require "socket"
require "thread"

begin
  require "openssl"
rescue LoadError => le
  puts "Could not load OpenSSL"
end

require "bunny/exceptions"
require "bunny/socket"

module Bunny
  class Transport

    #
    # API
    #

    DEFAULT_CONNECTION_TIMEOUT = 5.0
    # same as in RabbitMQ Java client
    DEFAULT_TLS_PROTOCOL       = "SSLv3"


    attr_reader :session, :host, :port, :socket, :connect_timeout, :read_write_timeout, :disconnect_timeout

    def initialize(session, host, port, opts)
      @session = session
      @host    = host
      @port    = port
      @opts    = opts

      @tls_enabled           = tls_enabled?(opts)
      @tls_certificate_path  = tls_certificate_path_from(opts)
      @tls_key_path          = tls_key_path_from(opts)
      @tls_certificate       = opts[:tls_certificate] || opts[:ssl_cert_string]
      @tls_key               = opts[:tls_key]         || opts[:ssl_key_string]
      @tls_certificate_store = opts[:tls_certificate_store]
      @verify_peer           = opts[:verify_ssl] || opts[:verify_peer] || opts[:verify_ssl].nil?

      @read_write_timeout = opts[:socket_timeout] || 1
      @read_write_timeout = nil if @read_write_timeout == 0
      @connect_timeout    = self.timeout_from(opts)
      @connect_timeout    = nil if @connect_timeout == 0
      @disconnect_timeout = @read_write_timeout || @connect_timeout

      initialize_socket
    end


    def hostname
      @host
    end

    def uses_tls?
      @tls_enabled
    end
    alias tls? uses_tls?

    def uses_ssl?
      @tls_enabled
    end
    alias ssl? uses_ssl?



    # Writes data to the socket. If read/write timeout was specified, Bunny::ClientTimeout will be raised
    # if the operation times out.
    #
    # @raise [ClientTimeout]
    def write(*args)
      begin
        raise Bunny::ConnectionError.new("No connection: socket is nil. ", @host, @port) if !@socket
        if @read_write_timeout
          Bunny::Timer.timeout(@read_write_timeout, Bunny::ClientTimeout) do
            @socket.write(*args) if open?
          end
        else
          @socket.write(*args) if open?
        end
      rescue Errno::EPIPE, Errno::EAGAIN, Bunny::ClientTimeout, Bunny::ConnectionError, IOError => e
        close

        @session.handle_network_failure(e)
      end
    end
    alias send_raw write

    def close(reason = nil)
      @socket.close if @socket and not @socket.closed?
      @socket   = nil
    end

    def open?
      !@socket.nil? && !@socket.closed?
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


    # Sends frame to the peer.
    #
    # @raise [ConnectionClosedError]
    # @private
    def send_frame(frame)
      if closed?
        @session.handle_network_failure(ConnectionClosedError.new(frame))
      else
        frame.encode_to_array.each do |component|
          send_raw(component)
        end
      end
    end


    def self.reacheable?(host, port, timeout)
      begin
        s = Bunny::Socket.open(host, port,
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


    protected

    def tls_enabled?(opts)
      opts[:tls] || opts[:ssl] || (opts[:port] == AMQ::Protocol::TLS_PORT) || false
    end

    def tls_certificate_path_from(opts)
      opts[:tsl_cert] || opts[:ssl_cert] || opts[:tsl_cert_path] || opts[:ssl_cert_path]
    end

    def tls_key_path_from(opts)
      opts[:tsl_key] || opts[:ssl_key] || opts[:tsl_key_path] || opts[:ssl_key_path]
    end

    def initialize_socket
      begin
        s = Bunny::Timer.timeout(@connect_timeout, ConnectionTimeout) do
          Bunny::Socket.open(@host, @port,
                             :keepalive      => @opts[:keepalive],
                             :socket_timeout => @connect_timeout)
        end

        @socket =  if uses_tls?
                     wrap_in_tls_socket(s)
                   else
                     s
                   end
      rescue StandardError, ConnectionTimeout => e
        @status = :not_connected
        raise Bunny::TCPConnectionFailed.new(e, self.hostname, self.port)
      end

      @socket
    end

    def wrap_in_tls_socket(socket)
      read_tls_keys!

      ctx = initialize_tls_context(OpenSSL::SSL::SSLContext.new(@opts.fetch(:tls_protocol, DEFAULT_TLS_PROTOCOL)))

      s = Bunny::SSLSocket.new(socket, ctx)
      s.sync_close = true
      s.connect
      s.post_connection_check(host) if @verify_peer
      s
    end

    def check_local_path!(s)
      raise ArgumentError, "cannot read TLS certificate or key from #{s}" unless File.file?(s) && File.readable?(s)
    end

    def read_tls_keys!
      if @tls_certificate_path
        check_local_path!(@tls_certificate_path)
        @tls_certificate = File.read(@tls_certificate_path)
      end
      if @tls_key_path
        check_local_path!(@tls_key_path)
        @tls_key         = File.read(@tls_key_path)
      end
    end

    def initialize_tls_context(ctx)
      ctx.cert       = OpenSSL::X509::Certificate.new(@tls_certificate) if @tls_certificate
      ctx.key        = OpenSSL::PKey::RSA.new(@tls_key) if @tls_key
      ctx.cert_store = @tls_certificate_store if @tls_certificate_store

      ctx
    end

    def timeout_from(options)
      options[:connect_timeout] || options[:connection_timeout] || options[:timeout] || DEFAULT_CONNECTION_TIMEOUT
    end
  end
end
