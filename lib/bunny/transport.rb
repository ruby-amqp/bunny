require "socket"
require "thread"
require "monitor"

begin
  require "openssl"
rescue LoadError => _le
  $stderr.puts "Could not load OpenSSL"
end

require "bunny/exceptions"
require "bunny/socket"

module Bunny
  # @private
  class Transport

    #
    # API
    #

    # Default TCP connection timeout
    DEFAULT_CONNECTION_TIMEOUT = 30.0

    DEFAULT_READ_TIMEOUT  = 30.0
    DEFAULT_WRITE_TIMEOUT = 30.0

    attr_reader :session, :host, :port, :socket, :connect_timeout, :read_timeout, :write_timeout, :disconnect_timeout
    attr_reader :tls_context, :verify_peer, :tls_ca_certificates, :tls_certificate_path, :tls_key_path

    def read_timeout=(v)
      @read_timeout = v
      @read_timeout = nil if @read_timeout == 0
    end

    def initialize(session, host, port, opts)
      @session        = session
      @session_error_handler = opts[:session_error_handler]
      @host    = host
      @port    = port
      @opts    = opts

      @logger                = session.logger
      @tls_enabled           = tls_enabled?(opts)

      @read_timeout = opts[:read_timeout] || DEFAULT_READ_TIMEOUT
      @read_timeout = nil if @read_timeout == 0

      @write_timeout = opts[:socket_timeout] # Backwards compatability

      @write_timeout ||= opts[:write_timeout] || DEFAULT_WRITE_TIMEOUT
      @write_timeout = nil if @write_timeout == 0

      @connect_timeout    = self.timeout_from(opts)
      @connect_timeout    = nil if @connect_timeout == 0
      @disconnect_timeout = @write_timeout || @read_timeout || @connect_timeout

      @writes_mutex       = @session.mutex_impl.new

      @socket = nil

      prepare_tls_context(opts) if @tls_enabled
    end

    def hostname
      @host
    end

    def local_address
      @socket.local_address
    end

    def uses_tls?
      @tls_enabled
    end
    alias tls? uses_tls?

    def uses_ssl?
      @tls_enabled
    end
    alias ssl? uses_ssl?


    def connect
      if uses_tls?
        begin
          @socket.connect
        rescue OpenSSL::SSL::SSLError => e
          @logger.error { "TLS connection failed: #{e.message}" }
          raise e
        end

        log_peer_certificate_info(Logger::DEBUG, @socket.peer_cert)
        log_peer_certificate_chain_info(Logger::DEBUG, @socket.peer_cert_chain)

        begin
          @socket.post_connection_check(host) if @verify_peer
        rescue OpenSSL::SSL::SSLError => e
          @logger.error do
            msg = "Peer verification of target server failed: #{e.message}. "
            msg += "Target hostname: #{hostname}, see peer certificate chain details below."
            msg
          end
          log_peer_certificate_info(Logger::ERROR, @socket.peer_cert)
          log_peer_certificate_chain_info(Logger::ERROR, @socket.peer_cert_chain)

          raise e
        end

        @status = :connected

        @socket
      else
        # no-op
      end
    end

    def connected?
      :connected == @status && open?
    end

    def configure_socket(&block)
      block.call(@socket) if @socket
    end

    def configure_tls_context(&block)
      block.call(@tls_context) if @tls_context
    end

    if defined?(JRUBY_VERSION)
      # Writes data to the socket.
      def write(data)
        return write_without_timeout(data) unless @write_timeout

        begin
          if open?
            @writes_mutex.synchronize do
              @socket.write(data)
            end
          end
        rescue SystemCallError, Timeout::Error, Bunny::ConnectionError, IOError => e
          @logger.error "Got an exception when sending data: #{e.message} (#{e.class.name})"
          close
          @status = :not_connected

          if @session.automatically_recover?
            @session.handle_network_failure(e)
          else
            @session_error_handler.raise(Bunny::NetworkFailure.new("detected a network failure: #{e.message}", e))
          end
        end
      end
    else
      # Writes data to the socket. If read/write timeout was specified the operation will return after that
      # amount of time has elapsed waiting for the socket.
      def write(data)
        return write_without_timeout(data) unless @write_timeout

        begin
          if open?
            @writes_mutex.synchronize do
              @socket.write_nonblock_fully(data, @write_timeout)
            end
          end
        rescue SystemCallError, Timeout::Error, Bunny::ConnectionError, IOError => e
          @logger.error "Got an exception when sending data: #{e.message} (#{e.class.name})"
          close
          @status = :not_connected

          if @session.automatically_recover?
            @session.handle_network_failure(e)
          else
            @session_error_handler.raise(Bunny::NetworkFailure.new("detected a network failure: #{e.message}", e))
          end
        end
      end
    end

    # Writes data to the socket without timeout checks
    def write_without_timeout(data, raise_exceptions = false)
      begin
        @writes_mutex.synchronize { @socket.write(data) }
        @socket.flush
      rescue SystemCallError, Bunny::ConnectionError, IOError => e
        close
        raise e if raise_exceptions

        if @session.automatically_recover?
          @session.handle_network_failure(e)
        else
          @session_error_handler.raise(Bunny::NetworkFailure.new("detected a network failure: #{e.message}", e))
        end
      end
    end

    # Sends frame to the peer.
    #
    # @raise [ConnectionClosedError]
    # @private
    def send_frame(frame)
      if closed?
        @session.handle_network_failure(ConnectionClosedError.new(frame))
      else
        write(frame.encode)
      end
    end

    # Sends frame to the peer without timeout control.
    #
    # @raise [ConnectionClosedError]
    # @private
    def send_frame_without_timeout(frame)
      if closed?
        @session.handle_network_failure(ConnectionClosedError.new(frame))
      else
        write_without_timeout(frame.encode)
      end
    end


    def close(reason = nil)
      @socket.close if open?
    end

    def open?
      @socket && !@socket.closed?
    end

    def closed?
      !open?
    end

    def flush
      @socket.flush if @socket
    end

    def read_fully(count)
      begin
        @socket.read_fully(count, @read_timeout)
      rescue SystemCallError, Timeout::Error, Bunny::ConnectionError, IOError => e
        @logger.error "Got an exception when receiving data: #{e.message} (#{e.class.name})"
        close
        @status = :not_connected

        if @session.automatically_recover?
          raise
        else
          @session_error_handler.raise(Bunny::NetworkFailure.new("detected a network failure: #{e.message}", e))
        end
      end
    end

    def read_ready?(timeout = nil)
      io = IO.select([@socket].compact, nil, nil, timeout)
      io && io[0].include?(@socket)
    end

    # Exposed primarily for Bunny::Channel
    # @private
    def read_next_frame(opts = {})
      header              = read_fully(7)
      type, channel, size = AMQ::Protocol::Frame.decode_header(header)
      payload             = if size > 0
                              read_fully(size)
                            else
                              ''
                            end
      frame_end = read_fully(1)

      # 1) the size is miscalculated
      if payload.bytesize != size
        raise BadLengthError.new(size, payload.bytesize)
      end

      # 2) the size is OK, but the string doesn't end with FINAL_OCTET
      raise NoFinalOctetError.new if frame_end != AMQ::Protocol::Frame::FINAL_OCTET
      AMQ::Protocol::Frame.new(type, payload, channel)
    end


    def self.reacheable?(host, port, timeout)
      begin
        s = Bunny::SocketImpl.open(host, port,
          :connect_timeout => timeout)

        true
      rescue SocketError, Timeout::Error => _e
        false
      ensure
        s.close if s
      end
    end

    def self.ping!(host, port, timeout)
      raise ConnectionTimeout.new("#{host}:#{port} is unreachable") if !reacheable?(host, port, timeout)
    end

    def initialize_socket
      begin
        @socket = Bunny::SocketImpl.open(@host, @port,
          :keepalive      => @opts[:keepalive],
          :connect_timeout => @connect_timeout)
      rescue StandardError, ClientTimeout => e
        @status = :not_connected
        raise Bunny::TCPConnectionFailed.new(e, self.hostname, self.port)
      end

      @socket
    end

    def maybe_initialize_socket
      initialize_socket if !@socket || closed?
    end

    def post_initialize_socket
      @socket = if uses_tls? and !@socket.is_a?(Bunny::SSLSocketImpl)
                  wrap_in_tls_socket(@socket)
                else
                  @socket
                end
    end

    protected

    def tls_enabled?(opts)
      return !!opts[:tls] unless opts[:tls].nil?
      return !!opts[:ssl] unless opts[:ssl].nil?
      (opts[:port] == AMQ::Protocol::TLS_PORT) || false
    end

    def tls_ca_certificates_paths_from(opts)
      Array(opts[:cacertfile] || opts[:tls_ca_certificates] || opts[:ssl_ca_certificates])
    end

    def tls_certificate_path_from(opts)
      opts[:certfile] || opts[:tls_cert] || opts[:ssl_cert] || opts[:tls_cert_path] || opts[:ssl_cert_path] || opts[:tls_certificate_path] || opts[:ssl_certificate_path]
    end

    def tls_key_path_from(opts)
      opts[:keyfile] || opts[:tls_key] || opts[:ssl_key] || opts[:tls_key_path] || opts[:ssl_key_path]
    end

    def tls_certificate_from(opts)
      begin
        read_client_certificate!
      rescue MissingTLSCertificateFile => _e
        inline_client_certificate_from(opts)
      end
    end

    def tls_key_from(opts)
      begin
        read_client_key!
      rescue MissingTLSKeyFile => _e
        inline_client_key_from(opts)
      end
    end

    def peer_certificate_info(peer_cert, prefix = "Peer's leaf certificate")
      exts = peer_cert.extensions.map { |x| x.value }
      # Subject Alternative Names
      sans = exts.select { |s| s =~ /^DNS/ }.map { |s| s.gsub(/^DNS:/, "") }

      msg = "#{prefix} subject: #{peer_cert.subject}, "
      msg += "subject alternative names: #{sans.join(', ')}, "
      msg += "issuer: #{peer_cert.issuer}, "
      msg += "not valid after: #{peer_cert.not_after}, "
      msg += "X.509 usage extensions: #{exts.join(', ')}"

      msg
    end

    def log_peer_certificate_info(severity, peer_cert, prefix = "Peer's leaf certificate")
      @logger.add(severity) { peer_certificate_info(peer_cert, prefix) }
    end

    def log_peer_certificate_chain_info(severity, chain)
      chain.each do |cert|
        self.log_peer_certificate_info(severity, cert, "Peer's certificate chain entry")
      end
    end

    def inline_client_certificate_from(opts)
      opts[:tls_certificate] || opts[:ssl_cert_string] || opts[:tls_cert]
    end

    def inline_client_key_from(opts)
      opts[:tls_key] || opts[:ssl_key_string]
    end

    def prepare_tls_context(opts)
      if opts.values_at(:verify_ssl, :verify_peer, :verify).all?(&:nil?)
        opts[:verify_peer] = true
      end

      # client cert/key paths
      @tls_certificate_path  = tls_certificate_path_from(opts)
      @tls_key_path          = tls_key_path_from(opts)
      # client cert/key
      @tls_certificate       = tls_certificate_from(opts)
      @tls_key               = tls_key_from(opts)
      @tls_certificate_store = opts[:tls_certificate_store]

      @verify_peer           = as_boolean(opts[:verify_ssl] || opts[:verify_peer] || opts[:verify])

      @tls_context = initialize_tls_context(OpenSSL::SSL::SSLContext.new, opts)
    end

    def as_boolean(val)
      case val
      when true    then true
      when false   then false
      when "true"  then true
      when "false" then false
      else
        !!val
      end
    end

    def wrap_in_tls_socket(socket)
      raise ArgumentError, "cannot wrap nil into TLS socket, @tls_context is nil. This is a Bunny bug." unless socket
      raise "cannot wrap a socket into TLS socket, @tls_context is nil. This is a Bunny bug." unless @tls_context

      s = Bunny::SSLSocketImpl.new(socket, @tls_context)

      # always set the SNI server name if possible since RFC 3546 and RFC 6066 both state
      # that TLS clients supporting the extensions can talk to TLS servers that do not
      s.hostname = @host if s.respond_to?(:hostname)

      s.sync_close = true
      s
    end

    def check_local_certificate_path!(s)
      raise MissingTLSCertificateFile, "cannot read client TLS certificate from #{s}" unless File.file?(s) && File.readable?(s)
    end

    def check_local_key_path!(s)
      raise MissingTLSKeyFile, "cannot read client TLS private key from #{s}" unless File.file?(s) && File.readable?(s)
    end

    def read_client_certificate!
      if @tls_certificate_path
        check_local_certificate_path!(@tls_certificate_path)
        @tls_certificate = File.read(@tls_certificate_path)
      end
    end

    def read_client_key!
      if @tls_key_path
        check_local_key_path!(@tls_key_path)
        @tls_key         = File.read(@tls_key_path)
      end
    end

    def initialize_tls_context(ctx, opts = {})
      ctx.cert       = OpenSSL::X509::Certificate.new(@tls_certificate) if @tls_certificate
      ctx.key        = OpenSSL::PKey.read(@tls_key) if @tls_key
      ctx.cert_store = if @tls_certificate_store
                         @tls_certificate_store
                       else
                         # this ivar exists so that this value can be exposed in the API
                         @tls_ca_certificates = tls_ca_certificates_paths_from(opts)
                         initialize_tls_certificate_store(@tls_ca_certificates)
                       end
      should_silence_warnings = opts.fetch(:tls_silence_warnings, false)

      if !@tls_certificate && !should_silence_warnings
        @logger.warn <<-MSG
Using TLS but no client certificate is provided. If RabbitMQ is configured to require & verify peer
certificate, connection will be rejected. Learn more at https://www.rabbitmq.com/ssl.html
        MSG
      end
      if @tls_certificate && !@tls_key
        @logger.warn "Using TLS but no client private key is provided!"
      end

      verify_mode = if @verify_peer
        OpenSSL::SSL::VERIFY_PEER|OpenSSL::SSL::VERIFY_FAIL_IF_NO_PEER_CERT
      else
        OpenSSL::SSL::VERIFY_NONE
      end
      @logger.debug { "Will use peer verification mode #{verify_mode}" }
      ctx.verify_mode = verify_mode

      if !@verify_peer && !should_silence_warnings
        @logger.warn <<-MSG
Using TLS but peer hostname verification is disabled. This is convenient for local development
but prone to man-in-the-middle attacks. Please set verify_peer: true in production. Learn more at https://www.rabbitmq.com/ssl.html
        MSG
      end

      ssl_version = opts[:tls_protocol] || opts[:ssl_version] || :TLSv1_2
      ctx.ssl_version = ssl_version if ssl_version

      ctx
    end

    def initialize_tls_certificate_store(certs)
      cert_files = []
      cert_inlines = []
      certs.each do |cert|
        # if it starts with / or C:/ then it's a file path that may or may not
        # exist (e.g. a default OpenSSL path). MK.
        if File.readable?(cert) || cert =~ /\A([a-z]:?)?\//i
          cert_files.push(cert)
        else
          cert_inlines.push(cert)
        end
      end
      @logger.debug { "Using CA certificates at #{cert_files.join(', ')}" }
      @logger.debug { "Using #{cert_inlines.count} inline CA certificates" }
      OpenSSL::X509::Store.new.tap do |store|
        store.set_default_paths
        cert_files.select { |path| File.readable?(path) }.
          each { |path| store.add_file(path) }
        cert_inlines.
          each { |cert| store.add_cert(OpenSSL::X509::Certificate.new(cert)) }
      end
    end

    def timeout_from(options)
      options[:connect_timeout] || options[:connection_timeout] || options[:timeout] || DEFAULT_CONNECTION_TIMEOUT
    end
  end
end
