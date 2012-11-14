require "socket"
require "thread"

require "bunny/exceptions"
require "bunny/socket"
require "bunny/command_assembler"

module Bunny
  class Transport

    #
    # API
    #

    DEFAULT_CONNECTION_TIMEOUT = 5.0


    attr_reader :host, :port, :socket, :connect_timeout

    def initialize(host, port, opts)
      @host = host
      @port = port
      @opts = opts

      @ssl             = opts[:ssl] || false
      @ssl_cert        = opts[:ssl_cert]
      @ssl_key         = opts[:ssl_key]
      @ssl_cert_string = opts[:ssl_cert_string]
      @ssl_key_string  = opts[:ssl_key_string]
      @verify_ssl      = opts[:verify_ssl].nil? || opts[:verify_ssl]

      @read_write_timeout = opts[:socket_timeout] || 3
      @read_write_timeout = nil if @read_write_timeout == 0
      @disconnect_timeout = @read_write_timeout || @connect_timeout
      @connect_timeout    = self.timeout_from(opts)

      @frames             = Hash.new { Array.new }

      initialize_socket
      initialize_command_assembler
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
        raise Bunny::ConnectionError.new('No connection - socket has not been created', @host, @port) if !@socket
        if @read_write_timeout
          Bunny::Timer.timeout(@read_write_timeout, Bunny::ClientTimeout) do
            @socket.write(*args)
          end
        else
          @socket.write(*args)
        end
      rescue Errno::EPIPE, Errno::EAGAIN, Bunny::ClientTimeout, IOError => e
        close!
        raise Bunny::ConnectionError, e.message
      end
    end
    alias send_raw write

    def flush
      @socket.flush
    end

    def read_fully(*args)
      @socket.read_fully(*args)
    end

    def open?
      !@socket.nil? && !@socket.closed?
    end

    def closed?
      !open?
    end

    def read_ready?(timeout)
      io = IO.select([@socket].compact, nil, nil, timeout)
      io && io[0].include?(@socket)
    end


    def close(reason = nil)
      @socket.close if @socket and not @socket.closed?
      @socket   = nil
    end


    # Exposed primarily for Bunny::Channel
    # @private
    def read_next_frame(opts = {})
      raise Bunny::ClientTimeout.new("I/O timeout") unless self.read_ready?(opts.fetch(:timeout, @read_write_timeout))

      @command_assembler.read_frame(@socket)
    end


    # Sends frame to the peer.
    #
    # @raise [ConnectionClosedError]
    # @private
    def send_frame(frame)
      if closed?
        raise ConnectionClosedError.new(frame)
      else
        send_raw(frame.encode)
      end
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
        close!
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

    def initialize_command_assembler
      @command_assembler = CommandAssembler.new
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
