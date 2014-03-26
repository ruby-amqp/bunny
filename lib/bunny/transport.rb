require "socket"
require "thread"
require "monitor"

begin
  require "openssl"
rescue LoadError => le
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
    DEFAULT_CONNECTION_TIMEOUT = 5.0
    # Default TLS protocol version to use.
    # Currently SSLv3, same as in RabbitMQ Java client
    DEFAULT_TLS_PROTOCOL       = "SSLv3"


    attr_reader :session, :host, :port, :socket, :connect_timeout, :read_write_timeout, :disconnect_timeout
    attr_reader :tls_context

    def initialize(session, host, port, opts)
      @session        = session
      @session_thread = opts[:session_thread]
      @host    = host
      @port    = port
      @opts    = opts

      @logger                = session.logger
      @tls_enabled           = tls_enabled?(opts)

      @read_write_timeout = opts[:socket_timeout] || 3
      @read_write_timeout = nil if @read_write_timeout == 0
      @connect_timeout    = self.timeout_from(opts)
      @connect_timeout    = nil if @connect_timeout == 0
      @disconnect_timeout = @read_write_timeout || @connect_timeout

      @writes_mutex       = @session.mutex_impl.new

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
      if uses_ssl?
        @socket.connect
        @socket.post_connection_check(host) if uses_tls? && @verify_peer

        @status = :connected

        @socket
      else
        # no-op
      end
    end

    def connected?
      :not_connected == @status && open?
    end

    def configure_socket(&block)
      block.call(@socket) if @socket
    end

    def configure_tls_context(&block)
      block.call(@tls_context) if @tls_context
    end

    # Writes data to the socket. If read/write timeout was specified, Bunny::ClientTimeout will be raised
    # if the operation times out.
    #
    # @raise [ClientTimeout]
    def write(data)
      begin
        if @read_write_timeout
          Bunny::Timeout.timeout(@read_write_timeout, Bunny::ClientTimeout) do
            if open?
              @writes_mutex.synchronize { @socket.write(data) }
              @socket.flush
            end
          end
        else
          if open?
            @writes_mutex.synchronize { @socket.write(data) }
            @socket.flush
          end
        end
      rescue SystemCallError, Bunny::ClientTimeout, Bunny::ConnectionError, IOError => e
        @logger.error "Got an exception when sending data: #{e.message} (#{e.class.name})"
        close
        @status = :not_connected

        if @session.automatically_recover?
          @session.handle_network_failure(e)
        else
          @session_thread.raise(Bunny::NetworkFailure.new("detected a network failure: #{e.message}", e))
        end
      end
    end

    # Writes data to the socket without timeout checks
    def write_without_timeout(data)
      begin
        @writes_mutex.synchronize { @socket.write(data) }
        @socket.flush
      rescue SystemCallError, Bunny::ConnectionError, IOError => e
        close

        if @session.automatically_recover?
          @session.handle_network_failure(e)
        else
          @session_thread.raise(Bunny::NetworkFailure.new("detected a network failure: #{e.message}", e))
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

    def read_fully(*args)
      @socket.read_fully(*args)
    end

    def read_ready?(timeout = nil)
      io = IO.select([@socket].compact, nil, nil, timeout)
      io && io[0].include?(@socket)
    end


    # Exposed primarily for Bunny::Channel
    # @private
    def read_next_frame(opts = {})
      header    = @socket.read_fully(7)
      # TODO: network issues here will sometimes cause
      #       the socket method return an empty string. We need to log
      #       and handle this better.
      # type, channel, size = begin
      #                         AMQ::Protocol::Frame.decode_header(header)
      #                       rescue AMQ::Protocol::EmptyResponseError => e
      #                         puts "Got AMQ::Protocol::EmptyResponseError, header is #{header.inspect}"
      #                       end
      type, channel, size = AMQ::Protocol::Frame.decode_header(header)
      payload   = @socket.read_fully(size)
      frame_end = @socket.read_fully(1)

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
          :socket_timeout => timeout)

        true
      rescue SocketError, Timeout::Error => e
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
          :socket_timeout => @connect_timeout)
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
      @socket = if uses_tls?
                  wrap_in_tls_socket(@socket)
                else
                  @socket
                end
    end

    protected

    def tls_enabled?(opts)
      opts[:tls] || opts[:ssl] || (opts[:port] == AMQ::Protocol::TLS_PORT) || false
    end

    def tls_certificate_path_from(opts)
      opts[:tls_cert] || opts[:ssl_cert] || opts[:tls_cert_path] || opts[:ssl_cert_path] || opts[:tls_certificate_path] || opts[:ssl_certificate_path]
    end

    def tls_key_path_from(opts)
      opts[:tls_key] || opts[:ssl_key] || opts[:tls_key_path] || opts[:ssl_key_path]
    end

    def tls_certificate_from(opts)
      begin
        read_client_certificate!
      rescue MissingTLSCertificateFile => e
        inline_client_certificate_from(opts)
      end
    end

    def tls_key_from(opts)
      begin
        read_client_key!
      rescue MissingTLSKeyFile => e
        inline_client_key_from(opts)
      end
    end


    def inline_client_certificate_from(opts)
      opts[:tls_certificate] || opts[:ssl_cert_string]
    end

    def inline_client_key_from(opts)
      opts[:tls_key] || opts[:ssl_key_string]
    end

    def prepare_tls_context(opts)
      # client cert/key paths
      @tls_certificate_path  = tls_certificate_path_from(opts)
      @tls_key_path          = tls_key_path_from(opts)
      # client cert/key
      @tls_certificate       = tls_certificate_from(opts)
      @tls_key               = tls_key_from(opts)
      @tls_certificate_store = opts[:tls_certificate_store]

      @tls_ca_certificates   = opts.fetch(:tls_ca_certificates, default_tls_certificates)
      @verify_peer           = opts[:verify_ssl] || opts[:verify_peer]

      @tls_context = initialize_tls_context(OpenSSL::SSL::SSLContext.new)
    end

    def wrap_in_tls_socket(socket)
      raise ArgumentError, "cannot wrap nil into TLS socket, @tls_context is nil. This is a Bunny bug." unless socket
      raise "cannot wrap a socket into TLS socket, @tls_context is nil. This is a Bunny bug." unless @tls_context

      s = Bunny::SSLSocketImpl.new(socket, @tls_context)
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

    def initialize_tls_context(ctx)
      ctx.cert       = OpenSSL::X509::Certificate.new(@tls_certificate) if @tls_certificate
      ctx.key        = OpenSSL::PKey::RSA.new(@tls_key) if @tls_key
      ctx.cert_store = if @tls_certificate_store
                         @tls_certificate_store
                       else
                         initialize_tls_certificate_store(@tls_ca_certificates)
                       end

      if !@tls_certificate
        @logger.warn <<-MSG
        Using TLS but no client certificate is provided! If RabbitMQ is configured to verify peer
        certificate, connection upgrade will fail!
        MSG
      end
      if @tls_certificate && !@tls_key
        @logger.warn "Using TLS but no client private key is provided!"
      end

      # setting TLS/SSL version only works correctly when done
      # vis set_params. MK.
      ctx.set_params(:ssl_version => @opts.fetch(:tls_protocol, DEFAULT_TLS_PROTOCOL))
     
      verify_mode = if @verify_peer
        OpenSSL::SSL::VERIFY_PEER|OpenSSL::SSL::VERIFY_FAIL_IF_NO_PEER_CERT
      else
        OpenSSL::SSL::VERIFY_NONE
      end

      ctx.set_params(:verify_mode => verify_mode)

      ctx
    end

    def default_tls_certificates
      if defined?(JRUBY_VERSION)
        # see https://github.com/jruby/jruby/issues/1055. MK.
        []
      else
        default_ca_file = ENV[OpenSSL::X509::DEFAULT_CERT_FILE_ENV] || OpenSSL::X509::DEFAULT_CERT_FILE
        default_ca_path = ENV[OpenSSL::X509::DEFAULT_CERT_DIR_ENV] || OpenSSL::X509::DEFAULT_CERT_DIR

        [
          default_ca_file,
          File.join(default_ca_path, 'ca-certificates.crt'), # Ubuntu/Debian
          File.join(default_ca_path, 'ca-bundle.crt'),       # Amazon Linux & Fedora/RHEL
          File.join(default_ca_path, 'ca-bundle.pem')        # OpenSUSE
          ].uniq
      end
    end

    def initialize_tls_certificate_store(certs)
      certs = certs.select { |path| File.readable? path }
      @logger.debug "Using CA certificates at #{certs.join(', ')}"
      if certs.empty?
        @logger.error "No CA certificates found, add one with :tls_ca_certificates"
      end
      OpenSSL::X509::Store.new.tap do |store|
        certs.each { |path| store.add_file(path) }
      end
    end

    def timeout_from(options)
      options[:connect_timeout] || options[:connection_timeout] || options[:timeout] || DEFAULT_CONNECTION_TIMEOUT
    end
  end
end
