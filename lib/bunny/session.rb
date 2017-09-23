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
    DEFAULT_CONTINUATION_TIMEOUT = 15000

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
    attr_reader :status, :port, :heartbeat, :user, :pass, :vhost, :frame_max, :channel_max, :threaded
    attr_reader :server_capabilities, :server_properties, :server_authentication_mechanisms, :server_locales
    attr_reader :channel_id_allocator
    # Authentication mechanism, e.g. "PLAIN" or "EXTERNAL"
    # @return [String]
    attr_reader :mechanism
    # @return [Logger]
    attr_reader :logger
    # @return [Integer] Timeout for blocking protocol operations (queue.declare, queue.bind, etc), in milliseconds. Default is 15000.
    attr_reader :continuation_timeout
    attr_reader :network_recovery_interval


    # @param [String, Hash] connection_string_or_opts Connection string or a hash of connection options
    # @param [Hash] optz Extra options not related to connection
    #
    # @option connection_string_or_opts [String] :host ("127.0.0.1") Hostname or IP address to connect to
    # @option connection_string_or_opts [Array<String>] :hosts (["127.0.0.1"]) list of hostname or IP addresses to select hostname from when connecting
    # @option connection_string_or_opts [Array<String>] :addresses (["127.0.0.1:5672"]) list of addresses to select hostname and port from when connecting
    # @option connection_string_or_opts [Integer] :port (5672) Port RabbitMQ listens on
    # @option connection_string_or_opts [String] :username ("guest") Username
    # @option connection_string_or_opts [String] :password ("guest") Password
    # @option connection_string_or_opts [String] :vhost ("/") Virtual host to use
    # @option connection_string_or_opts [Integer, Symbol] :heartbeat (:server) Heartbeat interval. :server means use the default suggested by RabbitMQ. 0 means no heartbeat (not recommended).
    # @option connection_string_or_opts [Integer] :network_recovery_interval (4) Recovery interval periodic network recovery will use. This includes initial pause after network failure.
    # @option connection_string_or_opts [Boolean] :tls (false) Should TLS/SSL be used?
    # @option connection_string_or_opts [String] :tls_cert (nil) Path to client TLS/SSL certificate file (.pem)
    # @option connection_string_or_opts [String] :tls_key (nil) Path to client TLS/SSL private key file (.pem)
    # @option connection_string_or_opts [Array<String>] :tls_ca_certificates Array of paths to TLS/SSL CA files (.pem), by default detected from OpenSSL configuration
    # @option connection_string_or_opts [String] :verify_peer (true) Whether TLS peer verification should be performed
    # @option connection_string_or_opts [Symbol] :tls_version (negotiated) What TLS version should be used (:TLSv1, :TLSv1_1, or :TLSv1_2)
    # @option connection_string_or_opts [Integer] :continuation_timeout (15000) Timeout for client operations that expect a response (e.g. {Bunny::Queue#get}), in milliseconds.
    # @option connection_string_or_opts [Integer] :connection_timeout (30) Timeout in seconds for connecting to the server.
    # @option connection_string_or_opts [Integer] :read_timeout (30) TCP socket read timeout in seconds.
    # @option connection_string_or_opts [Integer] :write_timeout (30) TCP socket write timeout in seconds.
    # @option connection_string_or_opts [Proc] :hosts_shuffle_strategy A Proc that reorders a list of host strings, defaults to Array#shuffle
    # @option connection_string_or_opts [Logger] :logger The logger.  If missing, one is created using :log_file and :log_level.
    # @option connection_string_or_opts [IO, String] :log_file The file or path to use when creating a logger.  Defaults to STDOUT.
    # @option connection_string_or_opts [IO, String] :logfile DEPRECATED: use :log_file instead.  The file or path to use when creating a logger.  Defaults to STDOUT.
    # @option connection_string_or_opts [Integer] :log_level The log level to use when creating a logger.  Defaults to LOGGER::WARN
    # @option connection_string_or_opts [Boolean] :automatically_recover (true) Should automatically recover from network failures?
    # @option connection_string_or_opts [Integer] :recovery_attempts (nil) Max number of recovery attempts, nil means forever
    # @option connection_string_or_opts [Integer] :reset_recovery_attempts_after_reconnection (true) Should recovery attempt counter be reset after successful reconnection? When set to false, the attempt counter will last through the entire lifetime of the connection object.
    # @option connection_string_or_opts [Boolean] :recover_from_connection_close (true) Should this connection recover after receiving a server-sent connection.close (e.g. connection was force closed)?
    #
    # @option optz [String] :auth_mechanism ("PLAIN") Authentication mechanism, PLAIN or EXTERNAL
    # @option optz [String] :locale ("PLAIN") Locale RabbitMQ should use
    #
    # @see http://rubybunny.info/articles/connecting.html Connecting to RabbitMQ guide
    # @see http://rubybunny.info/articles/tls.html TLS/SSL guide
    # @api public
    def initialize(connection_string_or_opts = ENV['RABBITMQ_URL'], optz = Hash.new)
      opts = case (connection_string_or_opts)
             when nil then
               Hash.new
             when String then
               self.class.parse_uri(connection_string_or_opts)
             when Hash then
               connection_string_or_opts
             end.merge(optz)

      @default_hosts_shuffle_strategy = Proc.new { |hosts| hosts.shuffle }

      @opts            = opts
      log_file         = opts[:log_file] || opts[:logfile] || STDOUT
      log_level        = opts[:log_level] || ENV["BUNNY_LOG_LEVEL"] || Logger::WARN
      # we might need to log a warning about ill-formatted IPv6 address but
      # progname includes hostname, so init like this first
      @logger          = opts.fetch(:logger, init_default_logger_without_progname(log_file, log_level))

      @addresses       = self.addresses_from(opts)
      @address_index   = 0

      # re-init, see above
      @logger          = opts.fetch(:logger, init_default_logger(log_file, log_level))

      @user            = self.username_from(opts)
      @pass            = self.password_from(opts)
      @vhost           = self.vhost_from(opts)
      @threaded        = opts.fetch(:threaded, true)

      validate_connection_options(opts)

      # should automatic recovery from network failures be used?
      @automatically_recover = if opts[:automatically_recover].nil? && opts[:automatic_recovery].nil?
                                 true
                               else
                                 opts[:automatically_recover] || opts[:automatic_recovery]
                               end
      @max_recovery_attempts = opts[:recovery_attempts]
      @recovery_attempts     = @max_recovery_attempts
      # When this is set, connection attempts won't be reset after
      # successful reconnection. Some find this behavior more sensible
      # than the per-failure attempt counter. MK.
      @reset_recovery_attempt_counter_after_reconnection = opts.fetch(:reset_recovery_attempts_after_reconnection, true)

      @network_recovery_interval = opts.fetch(:network_recovery_interval, DEFAULT_NETWORK_RECOVERY_INTERVAL)
      @recover_from_connection_close = opts.fetch(:recover_from_connection_close, true)
      # in ms
      @continuation_timeout   = opts.fetch(:continuation_timeout, DEFAULT_CONTINUATION_TIMEOUT)

      @status             = :not_connected
      @blocked            = false

      # these are negotiated with the broker during the connection tuning phase
      @client_frame_max   = opts.fetch(:frame_max, DEFAULT_FRAME_MAX)
      @client_channel_max = normalize_client_channel_max(opts.fetch(:channel_max, DEFAULT_CHANNEL_MAX))
      # will be-renegotiated during connection tuning steps. MK.
      @channel_max        = @client_channel_max
      @client_heartbeat   = self.heartbeat_from(opts)

      client_props         = opts[:properties] || opts[:client_properties] || {}
      @client_properties   = DEFAULT_CLIENT_PROPERTIES.merge(client_props)
      @mechanism           = opts.fetch(:auth_mechanism, "PLAIN")
      @credentials_encoder = credentials_encoder_for(@mechanism)
      @locale              = @opts.fetch(:locale, DEFAULT_LOCALE)

      @mutex_impl          = @opts.fetch(:mutex_impl, Monitor)

      # mutex for the channel id => channel hash
      @channel_mutex       = @mutex_impl.new
      # transport operations/continuations mutex. A workaround for
      # the non-reentrant Ruby mutexes. MK.
      @transport_mutex     = @mutex_impl.new
      @status_mutex        = @mutex_impl.new
      @address_index_mutex = @mutex_impl.new

      @channels            = Hash.new

      @origin_thread       = Thread.current

      self.reset_continuations
      self.initialize_transport
    end

    def validate_connection_options(options)
      if options[:hosts] && options[:addresses]
        raise ArgumentError, "Connection options can't contain hosts and addresses at the same time"
      end

      if (options[:host] || options[:hostname]) && (options[:hosts] || options[:addresses])
        @logger.warn "Connection options contain both a host and an array of hosts (addresses), please pick one."
      end
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

    def host
      @transport ? @transport.host : host_from_address(@addresses[@address_index])
    end

    def port
      @transport ? @transport.port : port_from_address(@addresses[@address_index])
    end

    def reset_address_index
      @address_index_mutex.synchronize { @address_index = 0 }
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

      @status_mutex.synchronize { @status = :connecting }
      # reset here for cases when automatic network recovery kicks in
      # when we were blocked. MK.
      @blocked       = false
      self.reset_continuations

      begin
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

        rescue TCPConnectionFailed => e
          @logger.warn e.message
          self.initialize_transport
          @logger.warn "Will try to connect to the next endpoint in line: #{@transport.host}:#{@transport.port}"

          return self.start
        rescue
          @status_mutex.synchronize { @status = :not_connected }
          raise
        end
      rescue HostListDepleted
        self.reset_address_index
        @status_mutex.synchronize { @status = :not_connected }
        raise TCPConnectionFailedForAllHosts
      end
      @status_mutex.synchronize { @manually_closed = false }

      self
    end

    # Socket operation write timeout used by this connection
    # @return [Integer]
    # @private
    def transport_write_timeout
      @transport.write_timeout
    end

    # Opens a new channel and returns it. This method will block the calling
    # thread until the response is received and the channel is guaranteed to be
    # opened (this operation is very fast and inexpensive).
    #
    # @return [Bunny::Channel] Newly opened channel
    def create_channel(n = nil, consumer_pool_size = 1, consumer_pool_abort_on_exception = false, consumer_pool_shutdown_timeout = 60)
      raise ArgumentError, "channel number 0 is reserved in the protocol and cannot be used" if 0 == n
      raise ConnectionAlreadyClosed if manually_closed?
      raise RuntimeError, "this connection is not open. Was Bunny::Session#start invoked? Is automatic recovery enabled?" if !connected?

      @channel_mutex.synchronize do
        if n && (ch = @channels[n])
          ch
        else
          ch = Bunny::Channel.new(self, n, ConsumerWorkPool.new(consumer_pool_size || 1, consumer_pool_abort_on_exception, consumer_pool_shutdown_timeout))
          ch.open
          ch
        end
      end
    end
    alias channel create_channel

    # Closes the connection. This involves closing all of its channels.
    def close
      @status_mutex.synchronize { @status = :closing }

      ignoring_io_errors do
        if @transport.open?
          close_all_channels

          self.close_connection(true)
        end

        clean_up_on_shutdown
      end
      @status_mutex.synchronize do
        @status = :closed
        @manually_closed = true
      end
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

    # @return [Boolean] true if this AMQP 0.9.1 connection is closing
    # @api private
    def closing?
      @status_mutex.synchronize { @status == :closing }
    end

    # @return [Boolean] true if this AMQP 0.9.1 connection is closed
    def closed?
      @status_mutex.synchronize { @status == :closed }
    end

    # @return [Boolean] true if this AMQP 0.9.1 connection has been programmatically closed
    def manually_closed?
      @status_mutex.synchronize { @manually_closed == true }
    end

    # @return [Boolean] true if this AMQP 0.9.1 connection is open
    def open?
      @status_mutex.synchronize do
        (status == :open || status == :connected || status == :connecting) && @transport.open?
      end
    end
    alias connected? open?

    # @return [Boolean] true if this connection has automatic recovery from network failure enabled
    def automatically_recover?
      @automatically_recover
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
      @channel_mutex.synchronize do
        n = ch.number
        self.register_channel(ch)

        @transport_mutex.synchronize do
          @transport.send_frame(AMQ::Protocol::Channel::Open.encode(n, AMQ::Protocol::EMPTY_STRING))
        end
        @last_channel_open_ok = wait_on_continuations
        raise_if_continuation_resulted_in_a_connection_error!

        @last_channel_open_ok
      end
    end

    # @private
    def close_channel(ch)
      @channel_mutex.synchronize do
        n = ch.number

        @transport.send_frame(AMQ::Protocol::Channel::Close.encode(n, 200, "Goodbye", 0, 0))
        @last_channel_close_ok = wait_on_continuations
        raise_if_continuation_resulted_in_a_connection_error!

        self.unregister_channel(ch)
        self.release_channel_id(ch.id)
        @last_channel_close_ok
      end
    end

    # @private
    def find_channel(number)
      @channels[number]
    end

    # @private
    def synchronised_find_channel(number)
      @channel_mutex.synchronize { @channels[number] }
    end

    # @private
    def close_all_channels
      @channel_mutex.synchronize do
        @channels.reject {|n, ch| n == 0 || !ch.open? }.each do |_, ch|
          Bunny::Timeout.timeout(@transport.disconnect_timeout, ClientTimeout) { ch.close }
        end
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
      @status_mutex.synchronize { @status = :not_connected }
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
      @logger.debug { "Session#handle_frame on #{ch_number}: #{method.inspect}" }
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
          ch = synchronised_find_channel(ch_number)
          # this includes sending a channel.close-ok and
          # potentially invoking a user-provided callback,
          # avoid doing that while holding a mutex lock. MK.
          ch.handle_method(method)
        ensure
          # synchronises on @channel_mutex under the hood
          self.unregister_channel(ch)
        end
      when AMQ::Protocol::Basic::GetEmpty then
        ch = find_channel(ch_number)
        ch.handle_basic_get_empty(method)
      else
        if ch = find_channel(ch_number)
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

      @status_mutex.synchronize { @status = :disconnected }

      if !recovering_from_network_failure?
        begin
          @recovering_from_network_failure = true
          if recoverable_network_failure?(exception)
            announce_network_failure_recovery
            @channel_mutex.synchronize do
              @channels.each do |n, ch|
                ch.maybe_kill_consumer_work_pool!
              end
            end
            @reader_loop.stop if @reader_loop
            maybe_shutdown_heartbeat_sender

            recover_from_network_failure
          else
            @logger.error "Exception #{exception.message} is considered unrecoverable..."
          end
        ensure
          @recovering_from_network_failure = false
        end
      end
    end

    # @private
    def recoverable_network_failure?(exception)
      # No reasonably smart strategy was suggested in a few years.
      # So just recover unconditionally. MK.
      true
    end

    # @private
    def recovering_from_network_failure?
      @recovering_from_network_failure
    end

    # @private
    def announce_network_failure_recovery
      if recovery_attempts_limited?
        @logger.warn "Will recover from a network failure (#{@recovery_attempts} out of #{@max_recovery_attempts} left)..."
      else
        @logger.warn "Will recover from a network failure (no retry limit)..."
      end
    end

    # @private
    def recover_from_network_failure
      sleep @network_recovery_interval
      @logger.debug "Will attempt connection recovery..."

      self.initialize_transport

      @logger.warn "Retrying connection on next host in line: #{@transport.host}:#{@transport.port}"
      self.start

      if open?

        @recovering_from_network_failure = false
        @logger.debug "Connection is now open"
        if @reset_recovery_attempt_counter_after_reconnection
          @logger.debug "Resetting recovery attempt counter after successful reconnection"
          reset_recovery_attempt_counter!
        else
          @logger.debug "Not resetting recovery attempt counter after successful reconnection, as configured"
        end

        recover_channels
      end
    rescue HostListDepleted
      reset_address_index
      retry
    rescue TCPConnectionFailedForAllHosts, TCPConnectionFailed, AMQ::Protocol::EmptyResponseError, SystemCallError => e
      @logger.warn "TCP connection failed, reconnecting in #{@network_recovery_interval} seconds"
      if should_retry_recovery?
        decrement_recovery_attemp_counter!
        if recoverable_network_failure?(e)
          announce_network_failure_recovery
          retry
        end
      else
        @logger.error "Ran out of recovery attempts (limit set to #{@max_recovery_attempts})"
      end
    end

    # @private
    def recovery_attempts_limited?
      !!@max_recovery_attempts
    end

    # @private
    def should_retry_recovery?
      !recovery_attempts_limited? || @recovery_attempts > 1
    end

    # @private
    def decrement_recovery_attemp_counter!
      @recovery_attempts -= 1 if @recovery_attempts
      @logger.debug "#{@recovery_attempts} recovery attempts left"
      @recovery_attempts
    end

    # @private
    def reset_recovery_attempt_counter!
      @recovery_attempts = @max_recovery_attempts
    end

    # @private
    def recover_channels
      @channel_mutex.synchronize do
        @channels.each do |n, ch|
          ch.open

          ch.recover_from_network_failure
        end
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
      if threaded?
        @origin_thread.raise(@last_connection_error)
      else
        raise @last_connection_error
      end
    end

    def clean_up_on_shutdown
      begin
        shut_down_all_consumer_work_pools!
        maybe_shutdown_reader_loop
        maybe_shutdown_heartbeat_sender
      rescue ShutdownSignal => _sse
        # no-op
      rescue Exception => e
        @logger.warn "Caught an exception when cleaning up after receiving connection.close: #{e.message}"
      ensure
        close_transport
      end
    end

    # @private
    def addresses_from(options)
      shuffle_strategy = options.fetch(:hosts_shuffle_strategy, @default_hosts_shuffle_strategy)

      addresses = options[:host] || options[:hostname] || options[:addresses] ||
        options[:hosts] || ["#{DEFAULT_HOST}:#{port_from(options)}"]
      addresses = [addresses] unless addresses.is_a? Array

      addrs = addresses.map do |address|
        host_with_port?(address) ? address : "#{address}:#{port_from(@opts)}"
      end

      shuffle_strategy.call(addrs)
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
    def host_with_port?(address)
      # we need to handle cases such as [2001:db8:85a3:8d3:1319:8a2e:370:7348]:5671
      last_colon                  = address.rindex(":")
      last_closing_square_bracket = address.rindex("]")

      if last_closing_square_bracket.nil?
        address.include?(":")
      else
        last_closing_square_bracket < last_colon
      end
    end

    # @private
    def host_from_address(address)
      # we need to handle cases such as [2001:db8:85a3:8d3:1319:8a2e:370:7348]:5671
      last_colon                  = address.rindex(":")
      last_closing_square_bracket = address.rindex("]")

      if last_closing_square_bracket.nil?
        parts = address.split(":")
        # this looks like an unquoted IPv6 address, so emit a warning
        if parts.size > 2
          @logger.warn "Address #{address} looks like an unquoted IPv6 address. Make sure you quote IPv6 addresses like so: [2001:db8:85a3:8d3:1319:8a2e:370:7348]"
        end
        return parts[0]
      end

      if last_closing_square_bracket < last_colon
        # there is a port
        address[0, last_colon]
      elsif last_closing_square_bracket > last_colon
        address
      end
    end

    # @private
    def port_from_address(address)
      # we need to handle cases such as [2001:db8:85a3:8d3:1319:8a2e:370:7348]:5671
      last_colon                  = address.rindex(":")
      last_closing_square_bracket = address.rindex("]")

      if last_closing_square_bracket.nil?
        parts = address.split(":")
        # this looks like an unquoted IPv6 address, so emit a warning
        if parts.size > 2
          @logger.warn "Address #{address} looks like an unquoted IPv6 address. Make sure you quote IPv6 addresses like so: [2001:db8:85a3:8d3:1319:8a2e:370:7348]"
        end
        return parts[1].to_i
      end

      if last_closing_square_bracket < last_colon
        # there is a port
        address[(last_colon + 1)..-1].to_i
      end
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
          @reader_loop.terminate_with(ShutdownSignal)
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

    # Sends multiple frames, in one go. For thread safety this method takes a channel
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
        # see rabbitmq/rabbitmq-server#156
        data = frames.reduce("") { |acc, frame| acc << frame.encode }
        @transport.write(data)
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
      oid = ("0x%x" % (self.object_id << 1))
      "#<#{self.class.name}:#{oid} #{@user}@#{host}:#{port}, vhost=#{@vhost}, addresses=[#{@addresses.join(',')}]>"
    end

    def inspect
      to_s
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

      @status_mutex.synchronize { @status = :connected }
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
              rescue
                nil
              end
      if frame.nil?
        raise TCPConnectionFailed.new('An empty frame was received while opening the connection. In RabbitMQ <= 3.1 this could mean an authentication issue.')
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
      @logger.debug { "Heartbeat interval negotiation: client = #{@client_heartbeat}, server = #{connection_tune.heartbeat}, result = #{@heartbeat}" }
      @logger.info "Heartbeat interval used (in seconds): #{@heartbeat}"

      # We set the read_write_timeout to twice the heartbeat value
      # This allows us to miss a single heartbeat before we time out the socket.
      #
      # Since RabbitMQ can be configured to disable heartbeats (bad idea but technically
      # possible nonetheless), we need to take both client and server values into
      # consideration when deciding about using the heartbeat value for read timeouts.
      @transport.read_timeout = if heartbeat_disabled?(@client_heartbeat) || heartbeat_disabled?(@heartbeat)
                                  @logger.debug { "Will use default socket read timeout of #{Transport::DEFAULT_READ_TIMEOUT}" }
                                  Transport::DEFAULT_READ_TIMEOUT
                                else
                                  # pad to account for edge cases. MK.
                                  n = @heartbeat * 2.2
                                  @logger.debug { "Will use socket read timeout of #{n}" }
                                  n
                                end


      # if there are existing channels we've just recovered from
      # a network failure and need to fix the allocated set. See issue 205. MK.
      if @channels.empty?
        @channel_id_allocator = ChannelIdAllocator.new(@channel_max)
      end

      @transport.send_frame(AMQ::Protocol::Connection::TuneOk.encode(@channel_max, @frame_max, @heartbeat))
      @logger.debug { "Sent connection.tune-ok with heartbeat interval = #{@heartbeat}, frame_max = #{@frame_max}, channel_max = #{@channel_max}" }
      @transport.send_frame(AMQ::Protocol::Connection::Open.encode(self.vhost))
      @logger.debug { "Sent connection.open with vhost = #{self.vhost}" }

      frame2 = begin
                 fr = @transport.read_next_frame
                 while fr.is_a?(AMQ::Protocol::HeartbeatFrame)
                   fr = @transport.read_next_frame
                 end
                 fr
                 # frame timeout means the broker has closed the TCP connection, which it
                 # does per 0.9.1 spec.
               rescue
                 nil
               end
      if frame2.nil?
        raise TCPConnectionFailed.new('An empty frame was received while opening the connection. In RabbitMQ <= 3.1 this could mean an authentication issue.')
      end
      connection_open_ok = frame2.decode_payload

      @status_mutex.synchronize { @status = :open }
      if @heartbeat && @heartbeat > 0
        initialize_heartbeat_sender
      end

      unless connection_open_ok.is_a?(AMQ::Protocol::Connection::OpenOk)
        if connection_open_ok.is_a?(AMQ::Protocol::Connection::Close)
          e = instantiate_connection_level_exception(connection_open_ok)
          begin
            shut_down_all_consumer_work_pools!
            maybe_shutdown_reader_loop
          rescue ShutdownSignal => _sse
            # no-op
          rescue Exception => e
            @logger.warn "Caught an exception when cleaning up after receiving connection.close: #{e.message}"
          ensure
            close_transport
          end

          if threaded?
            @origin_thread.raise(e)
          else
            raise e
          end
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
      if address = @addresses[ @address_index ]
        @address_index_mutex.synchronize { @address_index += 1 }
        @transport.close rescue nil # Let's make sure the previous transport socket is closed
        @transport = Transport.new(self,
                                   host_from_address(address),
                                   port_from_address(address),
                                   @opts.merge(:session_thread => @origin_thread)
                                  )

        # Reset the cached progname for the logger only when no logger was provided
        @default_logger.progname = self.to_s

        @transport
      else
        raise HostListDepleted
      end
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
    def init_default_logger(logfile, level)
      @default_logger = begin
                          lgr = ::Logger.new(logfile)
                          lgr.level    = normalize_log_level(level)
                          lgr.progname = self.to_s
                          lgr
                        end
    end

    # @private
    def init_default_logger_without_progname(logfile, level)
      @default_logger = begin
                          lgr = ::Logger.new(logfile)
                          lgr.level    = normalize_log_level(level)
                          lgr
                        end
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

    def ignoring_io_errors(&block)
      begin
        block.call
      rescue AMQ::Protocol::EmptyResponseError, IOError, SystemCallError, Bunny::NetworkFailure => _
        # ignore
      end
    end
  end # Session

  # backwards compatibility
  Client = Session
end
