require "socket"
require "thread"

require "bunny/socket"
require "bunny/heartbeat_sender"

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

    DEFAULT_CONNECTION_TIMEOUT = 5.0
    # backwards compatibility
    CONNECT_TIMEOUT   = DEFAULT_CONNECTION_TIMEOUT


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

    attr_reader :status, :host, :port, :heartbeat, :user, :pass, :vhost, :frame_max, :default_channel
    attr_reader :server_capabilities, :server_properties, :server_authentication_mechanisms, :server_locales
    attr_reader :default_channel

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
      @ssl             = opts[:ssl] || false
      @ssl_cert        = opts[:ssl_cert]
      @ssl_key         = opts[:ssl_key]
      @ssl_cert_string = opts[:ssl_cert_string]
      @ssl_key_string  = opts[:ssl_key_string]
      @verify_ssl      = opts[:verify_ssl].nil? || opts[:verify_ssl]

      @status          = :not_connected
      @frame_max       = opts[:frame_max] || DEFAULT_FRAME_MAX
      # currently ignored
      @channel_max     = opts[:channel_max] || 0
      @heartbeat       = self.heartbeat_from(opts)
      @connect_timeout = self.timeout_from(opts)

      @client_properties  = opts[:properties] || DEFAULT_CLIENT_PROPERTIES
      @mechanism          = "PLAIN"
      @locale             = @opts.fetch(:locale, DEFAULT_LOCALE)

      @read_write_timeout = opts[:socket_timeout] || 3
      @read_write_timeout = nil if @read_write_timeout == 0
      @disconnect_timeout = @read_write_timeout || @connect_timeout

      @frames             = Hash.new { Array.new }

      @channel_mutex      = Mutex.new
      @channels           = Hash.new

      # Create channel 0
      @channel0           = Bunny::Channel.new(self, 0)
    end

    def hostname;     self.host;  end
    def username;     self.user;  end
    def password;     self.pass;  end
    def virtual_host; self.vhost; end

    def uses_tls?
      @ssl
    end
    alias tls? uses_tls?

    def uses_ssl?
      @ssl
    end
    alias ssl? uses_ssl?

    def channel0
      @channel0
    end

    def channel
      @default_channel
    end


    def start
      @status = :connecting

      self.make_sure_socket_is_initialized
      self.init_connection
      self.open_connection

      @default_channel = self.create_channel
    end


    def create_channel
      ch = Bunny::Channel.new(self)
      ch.open
      ch
    end

    def close
      if socket_open?
        close_all_channels

        Bunny::Timer.timeout(@disconnect_timeout, ClientTimeout) { self.close_connection }
      end
    end
    alias stop close


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


    #
    # Implementation
    #

    # Writes data to the socket. If read/write timeout was specified, Bunny::ClientTimeout will be raised
    # if the operation times out.
    #
    # @raise [ClientTimeout]
    def write(*args)
      begin
        raise Bunny::ConnectionError, 'No connection - socket has not been created' if !@socket
        if @read_write_timeout
          Bunny::Timer.timeout(@read_write_timeout, Bunny::ClientTimeout) do
            @socket.write(*args)
          end
        else
          @socket.write(*args)
        end
      rescue Errno::EPIPE, Errno::EAGAIN, Bunny::ClientTimeout, IOError => e
        close_socket
        raise Bunny::ConnectionError, e.message
      end
    end
    alias send_raw write

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

    def timeout_from(options)
      options[:connect_timeout] || options[:connection_timeout] || options[:timeout] || DEFAULT_CONNECTION_TIMEOUT
    end

    def heartbeat_from(options)
      options[:heartbeat] || options[:heartbeat_interval] || options[:requested_heartbeat] || DEFAULT_HEARTBEAT
    end

    def open_channel(ch)
      n = ch.number

      Bunny::Timer.timeout(@disconnect_timeout, ClientTimeout) do
        self.send_frame(AMQ::Protocol::Channel::Open.encode(n, AMQ::Protocol::EMPTY_STRING))
      end

      # TODO: check the response
      frame  = self.read_next_frame
      method = frame.decode_payload

      self.register_channel(ch)
    end

    def close_channel(ch)
      n = ch.number

      Bunny::Timer.timeout(@disconnect_timeout, ClientTimeout) do
        self.send_frame(AMQ::Protocol::Channel::Close.encode(n, 200, "Goodbye", 0, 0))
      end

      # TODO: check the response
      frame  = self.read_next_frame
      method = frame.decode_payload

      self.unregister_channel(ch)
    end

    def close_all_channels
      @channels.reject {|n, ch| n == 0 || !ch.open? }.each do |_, ch|
        Bunny::Timer.timeout(@disconnect_timeout, ClientTimeout) { ch.close }
      end
    end

    def register_channel(ch)
      @channel_mutex.synchronize do
        @channels[ch.number] = ch
      end
    end

    def unregister_channel(ch)
      @channel_mutex.synchronize do
        @channels.delete(ch.number)
      end
    end

    def read_ready?(timeout)
      readable, _, _ = IO.select(@socket, nil, nil, timeout)
      readable && readable.include?(socket)
    end

    # Exposed primarily for Bunny::Channel
    # @private
    def read_next_frame(opts = {})
      raise Bunny::ClientTimeout.new("I/O timeout") unless self.read_ready?(opts.fetch(:timeout, @read_write_timeout))

      frame = Bunny::Framing::IO::Frame.decode(@socket)
      @heartbeat_sender.signal_activity! if @heartbeat_sender

      frame
    end

    def read_fully(*args)
      @socket.read_fully(*args)
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
        self.send_raw(frame.encode)
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
        frames.each { |frame| self.send_frame(frame) }
      end
    end # send_frameset(frames)

    protected

    def socket_open?
      !@socket.nil? && !@socket.closed?
    end

    def init_connection
      self.send_preamble

      connection_start = read_next_frame.decode_payload

      @server_properties                = connection_start.server_properties
      @server_capabilities              = @server_properties["capabilities"]

      @server_authentication_mechanisms = (connection_start.mechanisms || "").split(" ")
      @server_locales                   = Array(connection_start.locales)

      @status = :connected
    end

    def open_connection
      self.send_frame(AMQ::Protocol::Connection::StartOk.encode(@client_properties, @mechanism, self.encode_credentials(username, password), @locale))

      frame = begin
                read_next_frame
                # frame timeout means the broker has closed the TCP connection, which it
                # does per 0.9.1 spec.
              rescue Errno::ECONNRESET, ClientTimeout => e
                nil
              end
      if frame.nil?
        self.close_all_channels
        @state = :closed
        raise Bunny::PossibleAuthenticationFailureError.new(self.user, self.vhost, self.password.size)
      end

      connection_tune = frame.decode_payload
      @frame_max      = connection_tune.frame_max.freeze
      @heartbeat      ||= connection_tune.heartbeat

      self.send_frame(AMQ::Protocol::Connection::TuneOk.encode(@channel_max, @frame_max, @heartbeat))
      self.send_frame(AMQ::Protocol::Connection::Open.encode(self.vhost))

      frame              = read_next_frame
      connection_open_ok = frame.decode_payload

      @status = :open
      if @heartbeat && @heartbeat > 0
        initialize_heartbeat_sender
      end

      raise "could not open connection: server did not respond with connection.open-ok" unless connection_open_ok.is_a?(AMQ::Protocol::Connection::OpenOk)
    end

    def initialize_heartbeat_sender
      @heartbeat_sender = HeartbeatSender.new(self)
      @heartbeat_sender.start(@heartbeat)
    end

    def close_connection
      self.send_frame(AMQ::Protocol::Connection::Close.encode(200, "Goodbye", 0, 0))

      method = self.read_next_frame.decode_payload
      if @heartbeat_sender
        @heartbeat_sender.stop
      end
      close_socket

      method
    end


    def make_sure_socket_is_initialized
      self.socket
    end

    # Sends AMQ protocol header (also known as preamble).
    def send_preamble
      self.send_raw(AMQ::Protocol::PREAMBLE)
    end


    # Reads data from the socket. If read/write timeout was specified, Bunny::ClientTimeout will be raised
    # if the operation times out.
    #
    # @raise [ClientTimeout]
    def read_raw(*args)
      begin
        raise Bunny::ConnectionError, 'No connection - socket has not been created' if !@socket
        if @read_write_timeout
          Bunny::Timer.timeout(@read_write_timeout, Bunny::ClientTimeout) do
            @socket.read(*args)
          end
        else
          @socket.read(*args)
        end
      rescue Errno::EPIPE, Errno::EAGAIN, Bunny::ClientTimeout, IOError => e
        close_socket
        raise Bunny::ConnectionError, e.message
      end
    end


    # Reads data from the socket, retries on SIGINT signals
    def read(*args)
      self.read_raw(*args)
      # Got a SIGINT while waiting; give any traps a chance to run
    rescue Errno::EINTR
      retry
    end

    def read_ready?(timeout, cancelator = nil)
      io = IO.select([@socket, cancelator].compact, nil, nil, timeout)
      io && io[0].include?(@socket)
    end

    def socket
      return @socket if @socket and (@status == :connected) and not @socket.closed?

      begin
        @socket = Bunny::Timer.timeout(@connect_timeout, ConnectionTimeout) do
          Bunny::Socket.open(host, port,
                             :keepalive      => @opts[:keepalive],
                             :socket_timeout => @connect_timeout)
        end

        if @ssl
          require 'openssl' unless defined? OpenSSL::SSL
          sslctx = OpenSSL::SSL::SSLContext.new
          initialize_client_pair(sslctx)
          @socket = OpenSSL::SSL::SSLSocket.new(@socket, sslctx)
          @socket.sync_close = true
          @socket.connect
          @socket.post_connection_check(host) if @verify_ssl
          @socket
        end
      rescue Exception => e
        @status = :not_connected
        raise Bunny::TCPConnectionFailed.new(e, self.hostname, self.port)
      end

      @socket
    end

    def close_socket(reason = nil)
      @socket.close if @socket and not @socket.closed?
      @socket   = nil
      @status   = :not_connected
    end

    def initialize_client_pair(sslctx)
      if @ssl_cert
        @ssl_cert_string = File.read(@ssl_cert)
      end
      if @ssl_key
        @ssl_key_string = File.read(@ssl_key)
      end

      sslctx.cert = OpenSSL::X509::Certificate.new(@ssl_cert_string) if @ssl_cert_string
      sslctx.key = OpenSSL::PKey::RSA.new(@ssl_key_string) if @ssl_key_string
      sslctx
    end


    # @api plugin
    # @see http://tools.ietf.org/rfc/rfc2595.txt RFC 2595
    def encode_credentials(username, password)
      "\0#{username}\0#{password}"
    end # encode_credentials(username, password)

    # Utility methods

    # Determines, whether the received frameset is ready to be further processed
    def frameset_complete?(frames)
      return false if frames.empty?
      first_frame = frames[0]
      first_frame.final? || (first_frame.method_class.has_content? && content_complete?(frames[1..-1]))
    end

    # Determines, whether given frame array contains full content body
    def content_complete?(frames)
      return false if frames.empty?
      header = frames[0]
      raise "Not a content header frame first: #{header.inspect}" unless header.kind_of?(AMQ::Protocol::HeaderFrame)
      header.body_size == frames[1..-1].inject(0) {|sum, frame| sum + frame.payload.size }
    end


    # Processes a single frame.
    #
    # @param [AMQ::Protocol::Frame] frame
    # @api plugin
    def receive_frame(frame)
      @frames[frame.channel] ||= Array.new
      @frames[frame.channel] << frame

      if frameset_complete?(@frames[frame.channel])
        receive_frameset(@frames[frame.channel])
        # for channel.close, frame.channel will be nil. MK.
        clear_frames_on(frame.channel) if @frames[frame.channel]
      end
    end


    # Processes a frameset by finding and invoking a suitable handler.
    # Heartbeat frames are treated in a special way: they simply update @last_server_heartbeat
    # value.
    #
    # @param [Array<AMQ::Protocol::Frame>] frames
    # @api plugin
    def receive_frameset(frames)
      frame = frames.first

      if AMQ::Protocol::HeartbeatFrame === frame
        @last_server_heartbeat = Time.now
      else
        # if callable = AMQ::Client::HandlersRegistry.find(frame.method_class)
        #   f = frames.shift
        #   callable.call(self, f, frames)
        # else
        #   raise MissingHandlerError.new(frames.first)
        # end
      end
    end
  end # Session

  # backwards compatibility
  Client = Session
end
