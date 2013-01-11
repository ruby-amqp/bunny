require "socket"
require "thread"

require "bunny/exceptions"
require "bunny/socket"

module Bunny
  class Transport

    #
    # API
    #

    DEFAULT_CONNECTION_TIMEOUT = 5.0


    attr_reader :session, :host, :port, :socket, :connect_timeout

    def initialize(session, host, port, opts)
      @session = session
      @host    = host
      @port    = port
      @opts    = opts

      @ssl             = opts[:ssl] || false
      @ssl_cert        = opts[:ssl_cert]
      @ssl_key         = opts[:ssl_key]
      @ssl_cert_string = opts[:ssl_cert_string]
      @ssl_key_string  = opts[:ssl_key_string]
      @verify_ssl      = opts[:verify_ssl].nil? || opts[:verify_ssl]

      @read_write_timeout = opts[:socket_timeout] || 1
      @read_write_timeout = nil if @read_write_timeout == 0
      @disconnect_timeout = @read_write_timeout || @connect_timeout
      @connect_timeout    = self.timeout_from(opts)

      @frames             = Hash.new { Array.new }

      initialize_socket
    end


    def hostname
      @host
    end

    def uses_tls?
      @ssl
    end
    alias tls? uses_tls?

    def uses_ssl?
      @ssl
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
      rescue Errno::EPIPE, Errno::EAGAIN, Bunny::ClientTimeout, IOError => e
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
        send_raw(frame.encode)
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

    def initialize_socket
      begin
        @socket = Bunny::Timer.timeout(@connect_timeout, ConnectionTimeout) do
          Bunny::Socket.open(@host, @port,
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

    def timeout_from(options)
      options[:connect_timeout] || options[:connection_timeout] || options[:timeout] || DEFAULT_CONNECTION_TIMEOUT
    end
  end
end
