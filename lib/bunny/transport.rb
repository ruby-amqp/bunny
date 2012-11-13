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


    def read_fully(*args)
      @socket.read_fully(*args)
    end

    def open?
      !@socket.nil? && !@socket.closed?
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

      frame = Bunny::Framing::IO::Frame.decode(@socket)
      @heartbeat_sender.signal_activity! if @heartbeat_sender

      frame
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


    def timeout_from(options)
      options[:connect_timeout] || options[:connection_timeout] || options[:timeout] || DEFAULT_CONNECTION_TIMEOUT
    end
  end
end
