require "socket"
require "thread"

require "bunny/transport"
require "bunny/channel_id_allocator"
require "bunny/heartbeat_sender"
require "bunny/main_loop"

require "bunny/concurrent/condition"

require "amq/protocol/client"
require "amq/settings"

module Bunny
  class Session

    DEFAULT_HOST      = "127.0.0.1"
    DEFAULT_VHOST     = "/"
    DEFAULT_USER      = "guest"
    DEFAULT_PASSWORD  = "guest"
    # 0 means "no heartbeat". This is the same default RabbitMQ Java client and amqp gem
    # use.
    DEFAULT_HEARTBEAT = 0
    # 128K
    DEFAULT_FRAME_MAX = 131072

    # backwards compatibility
    CONNECT_TIMEOUT   = Transport::DEFAULT_CONNECTION_TIMEOUT


    DEFAULT_CLIENT_PROPERTIES = {
      # once we support AMQP 0.9.1 extensions, this needs to be updated. MK.
      :capabilities => {},
      :product      => "Bunny",
      :platform     => ::RUBY_DESCRIPTION,
      :version      => Bunny::VERSION,
      :information  => "http://github.com/ruby-amqp/bunny"
    }

    DEFAULT_LOCALE = "en_GB"


    #
    # API
    #

    attr_reader :status, :host, :port, :heartbeat, :user, :pass, :vhost, :frame_max
    attr_reader :server_capabilities, :server_properties, :server_authentication_mechanisms, :server_locales
    attr_reader :default_channel
    attr_reader :channel_id_allocator

    def initialize(connection_string_or_opts = Hash.new, optz = Hash.new)
      opts = case connection_string_or_opts
             when String then
               AMQ::Settings.parse_amqp_url(connection_string_or_opts)
             when Hash then
               connection_string_or_opts
             end.merge(optz)

      @opts            = opts
      @host            = self.hostname_from(opts)
      @port            = self.port_from(opts)
      @user            = self.username_from(opts)
      @pass            = self.password_from(opts)
      @vhost           = self.vhost_from(opts)
      @logfile         = opts[:logfile]
      @logging         = opts[:logging] || false

      @status          = :not_connected
      @frame_max       = opts[:frame_max] || DEFAULT_FRAME_MAX
      # currently ignored
      @channel_max     = opts[:channel_max] || 0
      @heartbeat       = self.heartbeat_from(opts)

      @client_properties  = opts[:properties] || DEFAULT_CLIENT_PROPERTIES
      @mechanism          = "PLAIN"
      @locale             = @opts.fetch(:locale, DEFAULT_LOCALE)

      @channel_id_allocator = ChannelIdAllocator.new
      @channel_mutex        = Mutex.new
      @channels             = Hash.new

      # Create channel 0
      @channel0           = Bunny::Channel.new(self, 0)

      @continuations      = ::Queue.new
    end

    def hostname;     self.host;  end
    def username;     self.user;  end
    def password;     self.pass;  end
    def virtual_host; self.vhost; end

    def uses_tls?
      @transport.uses_tls?
    end
    alias tls? uses_tls?

    def uses_ssl?
      @transport.uses_ssl?
    end
    alias ssl? uses_ssl?

    def channel0
      @channel0
    end

    def start
      @status = :connecting

      self.initialize_transport

      self.init_connection
      self.open_connection

      self.start_main_loop

      @default_channel = self.create_channel
    end


    def create_channel(n = nil)
      if n && (ch = @channels[n])
        ch
      else
        ch = Bunny::Channel.new(self, n)
        ch.open
        ch
      end
    end
    alias channel create_channel

    def close
      if @transport.open?
        close_all_channels

        Bunny::Timer.timeout(@disconnect_timeout, ClientTimeout) do
          self.close_connection(false)
        end
      end
    end
    alias stop close

    def with_channel(n = nil)
      ch = create_channel(n)
      yield ch
      ch.close

      self
    end


    def connecting?
      status == :connecting
    end

    def closed?
      status == :closed
    end

    def open?
      status == :open || status == :connected
    end
    alias connected? open?

    def prefetch(prefetch_count)
      self.basic_qos(prefetch_count, true)
    end


    #
    # Backwards compatibility
    #

    def queue(*args)
      @default_channel.queue(*args)
    end

    def direct(*args)
      @default_channel.direct(*args)
    end

    def fanout(*args)
      @default_channel.fanout(*args)
    end

    def topic(*args)
      @default_channel.topic(*args)
    end

    def headers(*args)
      @default_channel.headers(*args)
    end

    def exchange(*args)
      @default_channel.exchange(*args)
    end


    #
    # Implementation
    #


    def open_channel(ch)
      n = ch.number
      self.register_channel(ch)

      @transport.send_frame(AMQ::Protocol::Channel::Open.encode(n, AMQ::Protocol::EMPTY_STRING))
      @last_channel_open_ok = @continuations.pop
      raise_if_continuation_resulted_in_a_connection_error!

      @last_channel_open_ok
    end

    def close_channel(ch)
      n = ch.number

      @transport.send_frame(AMQ::Protocol::Channel::Close.encode(n, 200, "Goodbye", 0, 0))
      @last_channel_close_ok = @continuations.pop
      raise_if_continuation_resulted_in_a_connection_error!

      self.unregister_channel(ch)
      @last_channel_close_ok
    end

    def close_all_channels
      @channels.reject {|n, ch| n == 0 || !ch.open? }.each do |_, ch|
        Bunny::Timer.timeout(@disconnect_timeout, ClientTimeout) { ch.close }
      end
    end

    def close_connection(sync = true)
      @transport.send_frame(AMQ::Protocol::Connection::Close.encode(200, "Goodbye", 0, 0))

      if @heartbeat_sender
        @heartbeat_sender.stop
      end
      @status   = :not_connected

      if sync
        @last_connection_close_ok = @continuations.pop
      end
    end

    def handle_frame(ch_number, method)
      # puts "Session#handle_frame on #{ch_number}: #{method.inspect}"
      case method
      when AMQ::Protocol::Channel::OpenOk then
        @continuations.push(method)
      when AMQ::Protocol::Channel::CloseOk then
        @continuations.push(method)
      when AMQ::Protocol::Connection::Close then
        @last_connection_error = instantiate_connection_level_exception(method)
        @contunuations.push(method)
      when AMQ::Protocol::Connection::CloseOk then
        @last_connection_close_ok = method
        begin
          @continuations.clear

          @event_loop.stop
          @event_loop = nil

          @transport.close
        rescue Exception => e
          puts e.class.name
          puts e.message
          puts e.backtrace
        ensure
          @active_continuation.notify_all if @active_continuation
          @active_continuation = false
        end
      when AMQ::Protocol::Channel::Close then
        begin
          ch = @channels[ch_number]
          ch.handle_method(method)
        ensure
          self.unregister_channel(ch)
        end
      when AMQ::Protocol::Basic::GetEmpty then
        @channels[ch_number].handle_basic_get_empty(method)
      else
        @channels[ch_number].handle_method(method)
      end
    end

    def raise_if_continuation_resulted_in_a_connection_error!
      raise @last_connection_error if @last_connection_error
    end

    def handle_frameset(ch_number, frames)
      method = frames.first

      case method
      when AMQ::Protocol::Basic::GetOk then
        @channels[ch_number].handle_basic_get_ok(*frames)
      when AMQ::Protocol::Basic::GetEmpty then
        @channels[ch_number].handle_basic_get_empty(*frames)
      when AMQ::Protocol::Basic::Return then
        @channels[ch_number].handle_basic_return(*frames)
      else
        @channels[ch_number].handle_frameset(*frames)
      end
    end

    def send_raw(*args)
      @transport.write(*args)
    end

    def instantiate_connection_level_exception(frame)
      case frame
      when AMQ::Protocol::Connection::Close then
        klass = case frame.reply_code
                when 504 then
                  ChannelError
                end

        klass.new("Connection-level error: #{frame.reply_text}", self, frame)
      end
    end

    def hostname_from(options)
      options[:host] || options[:hostname] || DEFAULT_HOST
    end

    def port_from(options)
      fallback = if options[:tls] || options[:ssl]
                   AMQ::Protocol::TLS_PORT
                 else
                   AMQ::Protocol::DEFAULT_PORT
                 end

      options.fetch(:port, fallback)
    end

    def vhost_from(options)
      options[:virtual_host] || options[:vhost] || DEFAULT_VHOST
    end

    def username_from(options)
      options[:username] || options[:user] || DEFAULT_USER
    end

    def password_from(options)
      options[:password] || options[:pass] || options [:pwd] || DEFAULT_PASSWORD
    end

    def heartbeat_from(options)
      options[:heartbeat] || options[:heartbeat_interval] || options[:requested_heartbeat] || DEFAULT_HEARTBEAT
    end

    def next_channel_id
      @channel_id_allocator.next_channel_id
    end

    def release_channel_id(i)
      @channel_id_allocator.release_channel_id(i)
    end

    def register_channel(ch)
      @channel_mutex.synchronize do
        @channels[ch.number] = ch
      end
    end

    def unregister_channel(ch)
      @channel_mutex.synchronize do
        n = ch.number

        self.release_channel_id(n)
        @channels.delete(ch.number)
      end
    end

    def start_main_loop
      @event_loop = MainLoop.new(@transport, self)
      @event_loop.start
    end

    def signal_activity!
      @heartbeat_sender.signal_activity! if @heartbeat_sender
    end


    # Sends frame to the peer, checking that connection is open.
    # Exposed primarily for Bunny::Channel
    #
    # @raise [ConnectionClosedError]
    # @private
    def send_frame(frame)
      if closed?
        raise ConnectionClosedError.new(frame)
      else
        @transport.send_raw(frame.encode)
      end
    end

    # Sends multiple frames, one by one. For thread safety this method takes a channel
    # object and synchronizes on it.
    #
    # @api public
    def send_frameset(frames, channel)
      # some developers end up sharing channels between threads and when multiple
      # threads publish on the same channel aggressively, at some point frames will be
      # delivered out of order and broker will raise 505 UNEXPECTED_FRAME exception.
      # If we synchronize on the channel, however, this is both thread safe and pretty fine-grained
      # locking. Note that "single frame" methods do not need this kind of synchronization. MK.
      channel.synchronize do
        frames.each { |frame| @transport.send_frame(frame) }
        @transport.flush
      end
    end # send_frameset(frames)

    protected

    def socket_open?
      !@socket.nil? && !@socket.closed?
    end

    def init_connection
      self.send_preamble

      connection_start = @transport.read_next_frame.decode_payload

      @server_properties                = connection_start.server_properties
      @server_capabilities              = @server_properties["capabilities"]

      @server_authentication_mechanisms = (connection_start.mechanisms || "").split(" ")
      @server_locales                   = Array(connection_start.locales)

      @status = :connected
    end

    def open_connection
      @transport.send_frame(AMQ::Protocol::Connection::StartOk.encode(@client_properties, @mechanism, self.encode_credentials(username, password), @locale))

      frame = begin
                @transport.read_next_frame
                # frame timeout means the broker has closed the TCP connection, which it
                # does per 0.9.1 spec.
              rescue Errno::ECONNRESET, ClientTimeout, AMQ::Protocol::EmptyResponseError, EOFError => e
                nil
              end
      if frame.nil?
        @state = :closed
        raise Bunny::PossibleAuthenticationFailureError.new(self.user, self.vhost, self.password.size)
      end

      connection_tune = frame.decode_payload
      @frame_max      = connection_tune.frame_max.freeze
      @heartbeat      ||= connection_tune.heartbeat

      @transport.send_frame(AMQ::Protocol::Connection::TuneOk.encode(@channel_max, @frame_max, @heartbeat))
      @transport.send_frame(AMQ::Protocol::Connection::Open.encode(self.vhost))

      frame2 = begin
                 @transport.read_next_frame
                 # frame timeout means the broker has closed the TCP connection, which it
                 # does per 0.9.1 spec.
               rescue Errno::ECONNRESET, ClientTimeout, AMQ::Protocol::EmptyResponseError, EOFError => e
                 nil
               end
      if frame2.nil?
        @state = :closed
        raise Bunny::PossibleAuthenticationFailureError.new(self.user, self.vhost, self.password.size)
      end
      connection_open_ok = frame2.decode_payload

      @status = :open
      if @heartbeat && @heartbeat > 0
        initialize_heartbeat_sender
      end

      raise "could not open connection: server did not respond with connection.open-ok" unless connection_open_ok.is_a?(AMQ::Protocol::Connection::OpenOk)
    end

    def initialize_heartbeat_sender
      @heartbeat_sender = HeartbeatSender.new(@transport)
      @heartbeat_sender.start(@heartbeat)
    end


    def initialize_transport
      @transport = Transport.new(@host, @port, @opts)
    end

    # Sends AMQ protocol header (also known as preamble).
    def send_preamble
      @transport.send_raw(AMQ::Protocol::PREAMBLE)
    end




    # @api plugin
    # @see http://tools.ietf.org/rfc/rfc2595.txt RFC 2595
    def encode_credentials(username, password)
      "\0#{username}\0#{password}"
    end # encode_credentials(username, password)
  end # Session

  # backwards compatibility
  Client = Session
end
