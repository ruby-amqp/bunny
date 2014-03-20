require "socket"
require "thread"
require "monitor"

require "bunny/transport"
require "bunny/channel_id_allocator"
require "bunny/heartbeat_sender"
require "bunny/reader_loop"
require "bunny/authentication/credentials_encoder"
require "bunny/authentication/plain_mechanism_encoder"
require "bunny/authentication/external_mechanism_encoder"

if defined?(JRUBY_VERSION)
  require "bunny/concurrent/linked_continuation_queue"
else
  require "bunny/concurrent/continuation_queue"
end

require "amq/protocol/client"
require "amq/settings"

module Bunny
  # Represents AMQP 0.9.1 connection (to a RabbitMQ node).
  # @see http://rubybunny.info/articles/connecting.html Connecting to RabbitMQ guide
  class Session

    # Default host used for connection
    DEFAULT_HOST      = "127.0.0.1"
    # Default virtual host used for connection
    DEFAULT_VHOST     = "/"
    # Default username used for connection
    DEFAULT_USER      = "guest"
    # Default password used for connection
    DEFAULT_PASSWORD  = "guest"
    # Default heartbeat interval, the same value as RabbitMQ 3.0 uses.
    DEFAULT_HEARTBEAT = :server
    # @private
    DEFAULT_FRAME_MAX = 131072
    # 2^16 - 1, maximum representable signed 16 bit integer.
    # @private
    CHANNEL_MAX_LIMIT   = 65535
    DEFAULT_CHANNEL_MAX = CHANNEL_MAX_LIMIT

    # backwards compatibility
    # @private
    CONNECT_TIMEOUT   = Transport::DEFAULT_CONNECTION_TIMEOUT

    # @private
    DEFAULT_CONTINUATION_TIMEOUT = if RUBY_VERSION.to_f < 1.9
                                     8000
                                   else
                                     4000
                                   end

    # RabbitMQ client metadata
    DEFAULT_CLIENT_PROPERTIES = {
      :capabilities => {
        :publisher_confirms           => true,
        :consumer_cancel_notify       => true,
        :exchange_exchange_bindings   => true,
        :"basic.nack"                 => true,
        :"connection.blocked"         => true,
        # See http://www.rabbitmq.com/auth-notification.html
        :authentication_failure_close => true
      },
      :product      => "Bunny",
      :platform     => ::RUBY_DESCRIPTION,
      :version      => Bunny::VERSION,
      :information  => "http://rubybunny.info",
    }

    # @private
    DEFAULT_LOCALE = "en_GB"

    # Default reconnection interval for TCP connection failures
    DEFAULT_NETWORK_RECOVERY_INTERVAL = 5.0


    #
    # API
    #

    # @return [Bunny::Transport]
    attr_reader :transport
    attr_reader :status, :host, :port, :heartbeat, :user, :pass, :vhost, :frame_max, :channel_max, :threaded
    attr_reader :server_capabilities, :server_properties, :server_authentication_mechanisms, :server_locales
    attr_reader :default_channel
    attr_reader :channel_id_allocator
    # Authentication mechanism, e.g. "PLAIN" or "EXTERNAL"
    # @return [String]
    attr_reader :mechanism
    # @return [Logger]
    attr_reader :logger
    # @return [Integer] Timeout for blocking protocol operations (queue.declare, queue.bind, etc), in milliseconds. Default is 4000.
    attr_reader :continuation_timeout


    # @param [String, Hash] connection_string_or_opts Connection string or a hash of connection options
    # @param [Hash] optz Extra options not related to connection
    #
    # @option connection_string_or_opts [String] :host ("127.0.0.1") Hostname or IP address to connect to
    # @option connection_string_or_opts [Integer] :port (5672) Port RabbitMQ listens on
    # @option connection_string_or_opts [String] :username ("guest") Username
    # @option connection_string_or_opts [String] :password ("guest") Password
    # @option connection_string_or_opts [String] :vhost ("/") Virtual host to use
    # @option connection_string_or_opts [Integer] :heartbeat (600) Heartbeat interval. 0 means no heartbeat.
    # @option connection_string_or_opts [Integer] :network_recovery_interval (4) Recovery interval periodic network recovery will use. This includes initial pause after network failure.
    # @option connection_string_or_opts [Boolean] :tls (false) Should TLS/SSL be used?
    # @option connection_string_or_opts [String] :tls_cert (nil) Path to client TLS/SSL certificate file (.pem)
    # @option connection_string_or_opts [String] :tls_key (nil) Path to client TLS/SSL private key file (.pem)
    # @option connection_string_or_opts [Array<String>] :tls_ca_certificates Array of paths to TLS/SSL CA files (.pem), by default detected from OpenSSL configuration
    # @option connection_string_or_opts [Integer] :continuation_timeout (4000) Timeout for client operations that expect a response (e.g. {Bunny::Queue#get}), in milliseconds.
    # @option connection_string_or_opts [Integer] :connection_timeout (5) Timeout in seconds for connecting to the server.
    #
    # @option optz [String] :auth_mechanism ("PLAIN") Authentication mechanism, PLAIN or EXTERNAL
    # @option optz [String] :locale ("PLAIN") Locale RabbitMQ should use
    #
    # @see http://rubybunny.info/articles/connecting.html Connecting to RabbitMQ guide
    # @see http://rubybunny.info/articles/tls.html TLS/SSL guide
    # @api public
    def initialize(connection_string_or_opts = Hash.new, optz = Hash.new)
      opts = case (ENV["RABBITMQ_URL"] || connection_string_or_opts)
             when nil then
               Hash.new
             when String then
               self.class.parse_uri(ENV["RABBITMQ_URL"] || connection_string_or_opts)
             when Hash then
               connection_string_or_opts
             end.merge(optz)

      @opts            = opts
      @host            = self.hostname_from(opts)
      @port            = self.port_from(opts)
      @user            = self.username_from(opts)
      @pass            = self.password_from(opts)
      @vhost           = self.vhost_from(opts)
      @logfile         = opts[:log_file] || opts[:logfile] || STDOUT
      @threaded        = opts.fetch(:threaded, true)

      @logger          = opts.fetch(:logger, init_logger(opts[:log_level] || ENV["BUNNY_LOG_LEVEL"] || Logger::WARN))

      # should automatic recovery from network failures be used?
      @automatically_recover = if opts[:automatically_recover].nil? && opts[:automatic_recovery].nil?
                                 true
                               else
                                 opts[:automatically_recover] || opts[:automatic_recovery]
                               end
      @network_recovery_interval = opts.fetch(:network_recovery_interval, DEFAULT_NETWORK_RECOVERY_INTERVAL)
      @recover_from_connection_close = opts.fetch(:recover_from_connection_close, false)
      # in ms
      @continuation_timeout      = opts.fetch(:continuation_timeout, DEFAULT_CONTINUATION_TIMEOUT)

      @status             = :not_connected
      @blocked            = false

      # these are negotiated with the broker during the connection tuning phase
      @client_frame_max   = opts.fetch(:frame_max, DEFAULT_FRAME_MAX)
      @client_channel_max = normalize_client_channel_max(opts.fetch(:channel_max, DEFAULT_CHANNEL_MAX))
      # will be-renegotiated during connection tuning steps. MK.
      @channel_max        = @client_channel_max
      @client_heartbeat   = self.heartbeat_from(opts)

      @client_properties   = opts[:properties] || DEFAULT_CLIENT_PROPERTIES
      @mechanism           = opts.fetch(:auth_mechanism, "PLAIN")
      @credentials_encoder = credentials_encoder_for(@mechanism)
      @locale              = @opts.fetch(:locale, DEFAULT_LOCALE)

      @mutex_impl          = @opts.fetch(:mutex_impl, Monitor)

      # mutex for the channel id => channel hash
      @channel_mutex       = @mutex_impl.new
      # transport operations/continuations mutex. A workaround for
      # the non-reentrant Ruby mutexes. MK.
      @transport_mutex     = @mutex_impl.new
      @channels            = Hash.new

      @origin_thread       = Thread.current

      self.reset_continuations
      self.initialize_transport
    end

    # @return [String] RabbitMQ hostname (or IP address) used
    def hostname;     self.host;  end
    # @return [String] Username used
    def username;     self.user;  end
    # @return [String] Password used
    def password;     self.pass;  end
    # @return [String] Virtual host used
    def virtual_host; self.vhost; end

    # @return [Integer] Heartbeat interval used
    def heartbeat_interval; self.heartbeat; end

    # @return [Boolean] true if this connection uses TLS (SSL)
    def uses_tls?
      @transport.uses_tls?
    end
    alias tls? uses_tls?

    # @return [Boolean] true if this connection uses TLS (SSL)
    def uses_ssl?
      @transport.uses_ssl?
    end
    alias ssl? uses_ssl?

    # @return [Boolean] true if this connection uses a separate thread for I/O activity
    def threaded?
      @threaded
    end

    # @private
    attr_reader :mutex_impl

    # Provides a way to fine tune the socket used by connection.
    # Accepts a block that the socket will be yielded to.
    def configure_socket(&block)
      raise ArgumentError, "No block provided!" if block.nil?

      @transport.configure_socket(&block)
    end

    # @return [Integer] Client socket port
    def local_port
      @transport.local_address.ip_port
    end

    # Starts the connection process.
    #
    # @see http://rubybunny.info/articles/getting_started.html
    # @see http://rubybunny.info/articles/connecting.html
    # @api public
    def start
      return self if connected?

      @status        = :connecting
      # reset here for cases when automatic network recovery kicks in
      # when we were blocked. MK.
      @blocked       = false
      self.reset_continuations

      begin
        # close existing transport if we have one,
        # to not leak sockets
        @transport.maybe_initialize_socket

        @transport.post_initialize_socket
        @transport.connect

        if @socket_configurator
          @transport.configure_socket(&@socket_configurator)
        end

        self.init_connection
        self.open_connection

        @reader_loop = nil
        self.start_reader_loop if threaded?

        @default_channel = self.create_channel
      rescue Exception => e
        @status = :not_connected
        raise e
      end

      self
    end

    # Socket operation timeout used by this connection
    # @return [Integer]
    # @private
    def read_write_timeout
      @transport.read_write_timeout
    end

    # Opens a new channel and returns it. This method will block the calling
    # thread until the response is received and the channel is guaranteed to be
    # opened (this operation is very fast and inexpensive).
    #
    # @return [Bunny::Channel] Newly opened channel
    def create_channel(n = nil, consumer_pool_size = 1)
      raise ArgumentError, "channel number 0 is reserved in the protocol and cannot be used" if 0 == n

      @channel_mutex.synchronize do
        if n && (ch = @channels[n])
          ch
        else
          ch = Bunny::Channel.new(self, n, ConsumerWorkPool.new(consumer_pool_size || 1))
          ch.open
          ch
        end
      end
    end
    alias channel create_channel

    # Closes the connection. This involves closing all of its channels.
    def close
      if @transport.open?
        close_all_channels

        Bunny::Timeout.timeout(@transport.disconnect_timeout, ClientTimeout) do
          self.close_connection(true)
        end
      end

      clean_up_on_shutdown
      @status = :closed
    end
    alias stop close

    # Creates a temporary channel, yields it to the block given to this
    # method and closes it.
    #
    # @return [Bunny::Session] self
    def with_channel(n = nil)
      ch = create_channel(n)
      begin
        yield ch
      ensure
        ch.close if ch.open?
      end

      self
    end

    # @return [Boolean] true if this connection is still not fully open
    def connecting?
      status == :connecting
    end

    # @return [Boolean] true if this AMQP 0.9.1 connection is closed
    def closed?
      status == :closed
    end

    # @return [Boolean] true if this AMQP 0.9.1 connection is open
    def open?
      (status == :open || status == :connected || status == :connecting) && @transport.open?
    end
    alias connected? open?

    # @return [Boolean] true if this connection has automatic recovery from network failure enabled
    def automatically_recover?
      @automatically_recover
    end

    #
    # Backwards compatibility
    #

    # @private
    def queue(*args)
      @default_channel.queue(*args)
    end

    # @private
    def direct(*args)
      @default_channel.direct(*args)
    end

    # @private
    def fanout(*args)
      @default_channel.fanout(*args)
    end

    # @private
    def topic(*args)
      @default_channel.topic(*args)
    end

    # @private
    def headers(*args)
      @default_channel.headers(*args)
    end

    # @private
    def exchange(*args)
      @default_channel.exchange(*args)
    end

    # Defines a callback that will be executed when RabbitMQ blocks the connection
    # because it is running low on memory or disk space (as configured via config file
    # and/or rabbitmqctl).
    #
    # @yield [AMQ::Protocol::Connection::Blocked] connection.blocked method which provides a reason for blocking
    #
    # @api public
    def on_blocked(&block)
      @block_callback = block
    end

    # Defines a callback that will be executed when RabbitMQ unblocks the connection
    # that was previously blocked, e.g. because the memory or disk space alarm has cleared.
    #
    # @see #on_blocked
    # @api public
    def on_unblocked(&block)
      @unblock_callback = block
    end

    # @return [Boolean] true if the connection is currently blocked by RabbitMQ because it's running low on
    #                   RAM, disk space, or other resource; false otherwise
    # @see #on_blocked
    # @see #on_unblocked
    def blocked?
      @blocked
    end

    # Parses an amqp[s] URI into a hash that {Bunny::Session#initialize} accepts.
    #
    # @param [String] uri amqp or amqps URI to parse
    # @return [Hash] Parsed URI as a hash
    def self.parse_uri(uri)
      AMQ::Settings.parse_amqp_url(uri)
    end

    # Checks if a queue with given name exists.
    #
    # Implemented using queue.declare
    # with passive set to true and a one-off (short lived) channel
    # under the hood.
    #
    # @param [String] name Queue name
    # @return [Boolean] true if queue exists
    def queue_exists?(name)
      ch = create_channel
      begin
        ch.queue(name, :passive => true)
        true
      rescue Bunny::NotFound => _
        false
      ensure
        ch.close if ch.open?
      end
    end

    # Checks if a exchange with given name exists.
    #
    # Implemented using exchange.declare
    # with passive set to true and a one-off (short lived) channel
    # under the hood.
    #
    # @param [String] name Exchange name
    # @return [Boolean] true if exchange exists
    def exchange_exists?(name)
      ch = create_channel
      begin
        ch.exchange(name, :passive => true)
        true
      rescue Bunny::NotFound => _
        false
      ensure
        ch.close if ch.open?
      end
    end


    #
    # Implementation
    #

    # @private
    def open_channel(ch)
      n = ch.number
      self.register_channel(ch)

      @transport_mutex.synchronize do
        @transport.send_frame(AMQ::Protocol::Channel::Open.encode(n, AMQ::Protocol::EMPTY_STRING))
      end
      @last_channel_open_ok = wait_on_continuations
      raise_if_continuation_resulted_in_a_connection_error!

      @last_channel_open_ok
    end

    # @private
    def close_channel(ch)
      @channel_mutex.synchronize do
        n = ch.number

        @transport.send_frame(AMQ::Protocol::Channel::Close.encode(n, 200, "Goodbye", 0, 0))
        @last_channel_close_ok = wait_on_continuations
        raise_if_continuation_resulted_in_a_connection_error!

        self.unregister_channel(ch)
        @last_channel_close_ok
      end
    end

    # @private
    def close_all_channels
      @channels.reject {|n, ch| n == 0 || !ch.open? }.each do |_, ch|
        Bunny::Timeout.timeout(@transport.disconnect_timeout, ClientTimeout) { ch.close }
      end
    end

    # @private
    def close_connection(sync = true)
      if @transport.open?
        @transport.send_frame(AMQ::Protocol::Connection::Close.encode(200, "Goodbye", 0, 0))

        if sync
          @last_connection_close_ok = wait_on_continuations
        end
      end

      shut_down_all_consumer_work_pools!
      maybe_shutdown_heartbeat_sender
      @status   = :not_connected
    end

    # Handles incoming frames and dispatches them.
    #
    # Channel methods (`channel.open-ok`, `channel.close-ok`) are
    # handled by the session itself.
    # Connection level errors result in exceptions being raised.
    # Deliveries and other methods are passed on to channels to dispatch.
    #
    # @private
    def handle_frame(ch_number, method)
      @logger.debug "Session#handle_frame on #{ch_number}: #{method.inspect}"
      case method
      when AMQ::Protocol::Channel::OpenOk then
        @continuations.push(method)
      when AMQ::Protocol::Channel::CloseOk then
        @continuations.push(method)
      when AMQ::Protocol::Connection::Close then
        if recover_from_connection_close?
          @logger.warn "Recovering from connection.close (#{method.reply_text})"
          clean_up_on_shutdown
          handle_network_failure(instantiate_connection_level_exception(method))
        else
          clean_up_and_fail_on_connection_close!(method)
        end
      when AMQ::Protocol::Connection::CloseOk then
        @last_connection_close_ok = method
        begin
          @continuations.clear
        rescue StandardError => e
          @logger.error e.class.name
          @logger.error e.message
          @logger.error e.backtrace
        ensure
          @continuations.push(:__unblock__)
        end
      when AMQ::Protocol::Connection::Blocked then
        @blocked = true
        @block_callback.call(method) if @block_callback
      when AMQ::Protocol::Connection::Unblocked then
        @blocked = false
        @unblock_callback.call(method) if @unblock_callback
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
        if ch = @channels[ch_number]
          ch.handle_method(method)
        else
          @logger.warn "Channel #{ch_number} is not open on this connection!"
        end
      end
    end

    # @private
    def raise_if_continuation_resulted_in_a_connection_error!
      raise @last_connection_error if @last_connection_error
    end

    # @private
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

    # @private
    def recover_from_connection_close?
      @recover_from_connection_close
    end

    # @private
    def handle_network_failure(exception)
      raise NetworkErrorWrapper.new(exception) unless @threaded

      @status = :disconnected

      if !recovering_from_network_failure?
        begin
          @recovering_from_network_failure = true
          if recoverable_network_failure?(exception)
            @logger.warn "Recovering from a network failure..."
            @channels.each do |n, ch|
              ch.maybe_kill_consumer_work_pool!
            end
            maybe_shutdown_heartbeat_sender

            recover_from_network_failure
          else
            # TODO: investigate if we can be a bit smarter here. MK.
          end
        ensure
          @recovering_from_network_failure = false
        end
      end
    end

    # @private
    def recoverable_network_failure?(exception)
      # TODO: investigate if we can be a bit smarter here. MK.
      true
    end

    # @private
    def recovering_from_network_failure?
      @recovering_from_network_failure
    end

    # @private
    def recover_from_network_failure
      begin
        sleep @network_recovery_interval
        @logger.debug "About to start connection recovery..."
        self.initialize_transport
        self.start

        if open?
          @recovering_from_network_failure = false

          recover_channels
        end
      rescue TCPConnectionFailed, AMQ::Protocol::EmptyResponseError => e
        @logger.warn "TCP connection failed, reconnecting in #{@network_recovery_interval} seconds"
        sleep @network_recovery_interval
        retry if recoverable_network_failure?(e)
      end
    end

    # @private
    def recover_channels
      # default channel is reopened right after connection
      # negotiation is completed, so make sure we do not try to open
      # it twice. MK.
      @channels.reject { |n, ch| ch == @default_channel }.each do |n, ch|
        ch.open

        ch.recover_from_network_failure
      end
    end

    # @private
    def instantiate_connection_level_exception(frame)
      case frame
      when AMQ::Protocol::Connection::Close then
        klass = case frame.reply_code
                when 320 then
                  ConnectionForced
                when 501 then
                  FrameError
                when 503 then
                  CommandInvalid
                when 504 then
                  ChannelError
                when 505 then
                  UnexpectedFrame
                when 506 then
                  ResourceError
                when 530 then
                  NotAllowedError
                when 541 then
                  InternalError
                else
                  raise "Unknown reply code: #{frame.reply_code}, text: #{frame.reply_text}"
                end

        klass.new("Connection-level error: #{frame.reply_text}", self, frame)
      end
    end

    def clean_up_and_fail_on_connection_close!(method)
      @last_connection_error = instantiate_connection_level_exception(method)
      @continuations.push(method)

      clean_up_on_shutdown
      @origin_thread.raise(@last_connection_error)
    end

    def clean_up_on_shutdown
      begin
        shut_down_all_consumer_work_pools!
        maybe_shutdown_reader_loop
        maybe_shutdown_heartbeat_sender
      rescue ShutdownSignal => sse
        # no-op
      rescue Exception => e
        @logger.warn "Caught an exception when cleaning up after receiving connection.close: #{e.message}"
      ensure
        close_transport
      end
    end

    # @private
    def hostname_from(options)
      options[:host] || options[:hostname] || DEFAULT_HOST
    end

    # @private
    def port_from(options)
      fallback = if options[:tls] || options[:ssl]
                   AMQ::Protocol::TLS_PORT
                 else
                   AMQ::Protocol::DEFAULT_PORT
                 end

      options.fetch(:port, fallback)
    end

    # @private
    def vhost_from(options)
      options[:virtual_host] || options[:vhost] || DEFAULT_VHOST
    end

    # @private
    def username_from(options)
      options[:username] || options[:user] || DEFAULT_USER
    end

    # @private
    def password_from(options)
      options[:password] || options[:pass] || options[:pwd] || DEFAULT_PASSWORD
    end

    # @private
    def heartbeat_from(options)
      options[:heartbeat] || options[:heartbeat_interval] || options[:requested_heartbeat] || DEFAULT_HEARTBEAT
    end

    # @private
    def next_channel_id
      @channel_id_allocator.next_channel_id
    end

    # @private
    def release_channel_id(i)
      @channel_id_allocator.release_channel_id(i)
    end

    # @private
    def register_channel(ch)
      @channel_mutex.synchronize do
        @channels[ch.number] = ch
      end
    end

    # @private
    def unregister_channel(ch)
      @channel_mutex.synchronize do
        n = ch.number

        self.release_channel_id(n)
        @channels.delete(ch.number)
      end
    end

    # @private
    def start_reader_loop
      reader_loop.start
    end

    # @private
    def reader_loop
      @reader_loop ||= ReaderLoop.new(@transport, self, Thread.current)
    end

    # @private
    def maybe_shutdown_reader_loop
      if @reader_loop
        @reader_loop.stop
        if threaded?
          # this is the easiest way to wait until the loop
          # is guaranteed to have terminated
          @reader_loop.raise(ShutdownSignal)
          # joining the thread here may take forever
          # on JRuby because sun.nio.ch.KQueueArrayWrapper#kevent0 is
          # a native method that cannot be (easily) interrupted.
          # So we use this ugly hack or else our test suite takes forever
          # to run on JRuby (a new connection is opened/closed per example). MK.
          if defined?(JRUBY_VERSION)
            sleep 0.075
          else
            @reader_loop.join
          end
        else
          # single threaded mode, nothing to do. MK.
        end
      end

      @reader_loop = nil
    end

    # @private
    def close_transport
      begin
        @transport.close
      rescue StandardError => e
        @logger.error "Exception when closing transport:"
        @logger.error e.class.name
        @logger.error e.message
        @logger.error e.backtrace
      end
    end

    # @private
    def signal_activity!
      @heartbeat_sender.signal_activity! if @heartbeat_sender
    end


    # Sends frame to the peer, checking that connection is open.
    # Exposed primarily for Bunny::Channel
    #
    # @raise [ConnectionClosedError]
    # @private
    def send_frame(frame, signal_activity = true)
      if open?
        # @transport_mutex.synchronize do
        #   @transport.write(frame.encode)
        # end
        @transport.write(frame.encode)
        signal_activity! if signal_activity
      else
        raise ConnectionClosedError.new(frame)
      end
    end

    # Sends frame to the peer, checking that connection is open.
    # Uses transport implementation that does not perform
    # timeout control. Exposed primarily for Bunny::Channel.
    #
    # @raise [ConnectionClosedError]
    # @private
    def send_frame_without_timeout(frame, signal_activity = true)
      if open?
        @transport.write_without_timeout(frame.encode)
        signal_activity! if signal_activity
      else
        raise ConnectionClosedError.new(frame)
      end
    end

    # Sends multiple frames, one by one. For thread safety this method takes a channel
    # object and synchronizes on it.
    #
    # @private
    def send_frameset(frames, channel)
      # some developers end up sharing channels between threads and when multiple
      # threads publish on the same channel aggressively, at some point frames will be
      # delivered out of order and broker will raise 505 UNEXPECTED_FRAME exception.
      # If we synchronize on the channel, however, this is both thread safe and pretty fine-grained
      # locking. Note that "single frame" methods do not need this kind of synchronization. MK.
      channel.synchronize do
        frames.each { |frame| self.send_frame(frame, false) }
        signal_activity!
      end
    end # send_frameset(frames)

    # Sends multiple frames, one by one. For thread safety this method takes a channel
    # object and synchronizes on it. Uses transport implementation that does not perform
    # timeout control.
    #
    # @private
    def send_frameset_without_timeout(frames, channel)
      # some developers end up sharing channels between threads and when multiple
      # threads publish on the same channel aggressively, at some point frames will be
      # delivered out of order and broker will raise 505 UNEXPECTED_FRAME exception.
      # If we synchronize on the channel, however, this is both thread safe and pretty fine-grained
      # locking. Note that "single frame" methods do not need this kind of synchronization. MK.
      channel.synchronize do
        frames.each { |frame| self.send_frame_without_timeout(frame, false) }
        signal_activity!
      end
    end # send_frameset_without_timeout(frames)

    # @private
    def send_raw_without_timeout(data, channel)
      # some developers end up sharing channels between threads and when multiple
      # threads publish on the same channel aggressively, at some point frames will be
      # delivered out of order and broker will raise 505 UNEXPECTED_FRAME exception.
      # If we synchronize on the channel, however, this is both thread safe and pretty fine-grained
      # locking. Note that "single frame" methods do not need this kind of synchronization. MK.
      channel.synchronize do
        @transport.write(data)
        signal_activity!
      end
    end # send_frameset_without_timeout(frames)

    # @return [String]
    # @api public
    def to_s
      "#<#{self.class.name}:#{object_id} #{@user}@#{@host}:#{@port}, vhost=#{@vhost}>"
    end

    protected

    # @private
    def init_connection
      self.send_preamble

      connection_start = @transport.read_next_frame.decode_payload

      @server_properties                = connection_start.server_properties
      @server_capabilities              = @server_properties["capabilities"]

      @server_authentication_mechanisms = (connection_start.mechanisms || "").split(" ")
      @server_locales                   = Array(connection_start.locales)

      @status = :connected
    end

    # @private
    def open_connection
      @transport.send_frame(AMQ::Protocol::Connection::StartOk.encode(@client_properties, @mechanism, self.encode_credentials(username, password), @locale))
      @logger.debug "Sent connection.start-ok"

      frame = begin
                fr = @transport.read_next_frame
                while fr.is_a?(AMQ::Protocol::HeartbeatFrame)
                  fr = @transport.read_next_frame
                end
                fr
                # frame timeout means the broker has closed the TCP connection, which it
                # does per 0.9.1 spec.
              rescue Errno::ECONNRESET, ClientTimeout, AMQ::Protocol::EmptyResponseError, EOFError, IOError => e
                nil
              end
      if frame.nil?
        @state = :closed
        @logger.error "RabbitMQ closed TCP connection before AMQP 0.9.1 connection was finalized. Most likely this means authentication failure."
        raise Bunny::PossibleAuthenticationFailureError.new(self.user, self.vhost, self.password.size)
      end

      response = frame.decode_payload
      if response.is_a?(AMQ::Protocol::Connection::Close)
        @state = :closed
        @logger.error "Authentication with RabbitMQ failed: #{response.reply_code} #{response.reply_text}"
        raise Bunny::AuthenticationFailureError.new(self.user, self.vhost, self.password.size)
      end



      connection_tune       = response

      @frame_max            = negotiate_value(@client_frame_max, connection_tune.frame_max)
      @channel_max          = negotiate_value(@client_channel_max, connection_tune.channel_max)
      # this allows for disabled heartbeats. MK.
      @heartbeat            = if heartbeat_disabled?(@client_heartbeat)
                                0
                              else
                                negotiate_value(@client_heartbeat, connection_tune.heartbeat)
                              end
      @logger.debug "Heartbeat interval negotiation: client = #{@client_heartbeat}, server = #{connection_tune.heartbeat}, result = #{@heartbeat}"
      @logger.info "Heartbeat interval used (in seconds): #{@heartbeat}"

      @channel_id_allocator = ChannelIdAllocator.new(@channel_max)

      @transport.send_frame(AMQ::Protocol::Connection::TuneOk.encode(@channel_max, @frame_max, @heartbeat))
      @logger.debug "Sent connection.tune-ok with heartbeat interval = #{@heartbeat}, frame_max = #{@frame_max}, channel_max = #{@channel_max}"
      @transport.send_frame(AMQ::Protocol::Connection::Open.encode(self.vhost))
      @logger.debug "Sent connection.open with vhost = #{self.vhost}"

      frame2 = begin
                 fr = @transport.read_next_frame
                 while fr.is_a?(AMQ::Protocol::HeartbeatFrame)
                   fr = @transport.read_next_frame
                 end
                 fr
                 # frame timeout means the broker has closed the TCP connection, which it
                 # does per 0.9.1 spec.
               rescue Errno::ECONNRESET, ClientTimeout, AMQ::Protocol::EmptyResponseError, EOFError => e
                 nil
               end
      if frame2.nil?
        @state = :closed
        @logger.warn "RabbitMQ closed TCP connection before AMQP 0.9.1 connection was finalized. Most likely this means authentication failure."
        raise Bunny::PossibleAuthenticationFailureError.new(self.user, self.vhost, self.password.size)
      end
      connection_open_ok = frame2.decode_payload

      @status = :open
      if @heartbeat && @heartbeat > 0
        initialize_heartbeat_sender
      end

      unless connection_open_ok.is_a?(AMQ::Protocol::Connection::OpenOk)
        if connection_open_ok.is_a?(AMQ::Protocol::Connection::Close)
          e = instantiate_connection_level_exception(connection_open_ok)
          begin
            shut_down_all_consumer_work_pools!
            maybe_shutdown_reader_loop
          rescue ShutdownSignal => sse
            # no-op
          rescue Exception => e
            @logger.warn "Caught an exception when cleaning up after receiving connection.close: #{e.message}"
          ensure
            close_transport
          end

          @origin_thread.raise(e)
        else
          raise "could not open connection: server did not respond with connection.open-ok but #{connection_open_ok.inspect} instead"
        end
      end
    end

    def heartbeat_disabled?(val)
      0 == val || val.nil?
    end

    # @private
    def negotiate_value(client_value, server_value)
      return server_value if client_value == :server

      if client_value == 0 || server_value == 0
        [client_value, server_value].max
      else
        [client_value, server_value].min
      end
    end

    # @private
    def initialize_heartbeat_sender
      maybe_shutdown_heartbeat_sender
      @logger.debug "Initializing heartbeat sender..."
      @heartbeat_sender = HeartbeatSender.new(@transport, @logger)
      @heartbeat_sender.start(@heartbeat)
    end

    # @private
    def maybe_shutdown_heartbeat_sender
      @heartbeat_sender.stop if @heartbeat_sender
    end

    # @private
    def initialize_transport
      @transport = Transport.new(self, @host, @port, @opts.merge(:session_thread => @origin_thread))
    end

    # @private
    def maybe_close_transport
      @transport.close if @transport
    end

    # Sends AMQ protocol header (also known as preamble).
    # @private
    def send_preamble
      @transport.write(AMQ::Protocol::PREAMBLE)
      @logger.debug "Sent protocol preamble"
    end


    # @private
    def encode_credentials(username, password)
      @credentials_encoder.encode_credentials(username, password)
    end # encode_credentials(username, password)

    # @private
    def credentials_encoder_for(mechanism)
      Authentication::CredentialsEncoder.for_session(self)
    end

    if defined?(JRUBY_VERSION)
      # @private
      def reset_continuations
        @continuations = Concurrent::LinkedContinuationQueue.new
      end
    else
      # @private
      def reset_continuations
        @continuations = Concurrent::ContinuationQueue.new
      end
    end

    # @private
    def wait_on_continuations
      unless @threaded
        reader_loop.run_once until @continuations.length > 0
      end

      @continuations.poll(@continuation_timeout)
    end

    # @private
    def init_logger(level)
      lgr          = ::Logger.new(@logfile)
      lgr.level    = normalize_log_level(level)
      lgr.progname = self.to_s

      lgr
    end

    # @private
    def normalize_log_level(level)
      case level
      when :debug, Logger::DEBUG, "debug" then Logger::DEBUG
      when :info,  Logger::INFO,  "info"  then Logger::INFO
      when :warn,  Logger::WARN,  "warn"  then Logger::WARN
      when :error, Logger::ERROR, "error" then Logger::ERROR
      when :fatal, Logger::FATAL, "fatal" then Logger::FATAL
      else
        Logger::WARN
      end
    end

    # @private
    def shut_down_all_consumer_work_pools!
      @channels.each do |_, ch|
        ch.maybe_kill_consumer_work_pool!
      end
    end

    def normalize_client_channel_max(n)
      return CHANNEL_MAX_LIMIT if n > CHANNEL_MAX_LIMIT

      case n
      when 0 then
        CHANNEL_MAX_LIMIT
      else
        n
      end
    end
  end # Session

  # backwards compatibility
  Client = Session
end
