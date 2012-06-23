require "socket"
require "thread"

require "amq/protocol/client"

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


    #
    # API
    #

    attr_reader :status, :host, :port, :heartbeat, :user, :pass, :vhost, :frame_max, :default_channel

    def initialize(connection_string_or_opts = Hash.new, optz = Hash.new)
      opts = case connection_string_or_opts
             when String then
               # TODO: move URI parsing to amq-protocol
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

      @client_properties = opts[:properties] || DEFAULT_CLIENT_PROPERTIES


      @channel_mutex     = Mutex.new
      @channels          = Hash.new
    end

    def hostname;     self.host;  end
    def username;     self.user;  end
    def password;     self.pass;  end
    def virtual_host; self.vhost; end

    def uses_tls?
      @ssl
    end

    def uses_ssl?
      @ssl
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
      @default_channel.open

      @status = :connected
    end


    def create_channel
      Bunny::Channel.new(self)
    end


    def close
    end
    alias stop close


    def connected?
      status == :connected
    end

    def connecting?
      status == :connecting
    end


    #
    # Implementation
    #

    def hostname_from(options)
      options[:host] || options[:hostname] || DEFAULT_HOST
    end

    def port_from(options)
      if options[:tls] || options[:ssl]
        AMQ::Protocol::TLS_PORT
      else
        options.fetch(:port, AMQ::Protocol::DEFAULT_PORT)
      end
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

    def register_channel(ch)
      @channel_mutex.synchronize do
        @channels[ch.id] = ch
      end
    end

    def unregister_channel(ch)
      @channel_mutex.synchronize do
        @channels[ch.id] = nil
      end
    end

    protected

    def init_connection
      self.send_preamble
      
    end

    def open_connection
      # TODO
    end

    def close_connection
      # TODO
    end


    def make_sure_socket_is_initialized
      self.socket
    end

    # Sends AMQ protocol header (also known as preamble).
    #
    # @see http://bit.ly/amqp091spec AMQP 0.9.1 specification (Section 2.2)
    def send_preamble
      self.send_raw(AMQ::Protocol::PREAMBLE)
    end

    # Sends frame to the peer, checking that connection is open.
    #
    # @raise [ConnectionClosedError]
    def send_frame(frame)
      if closed?
        raise ConnectionClosedError.new(frame)
      else
        self.send_raw(frame.encode)
      end
    end

    # Sends raw bytes to the peer
    def send_raw(*args)
      send_via_socket(:write, *args)
    end

    # Sends data down the TCP socket
    def send_via_socket(cmd, *args)
      begin
        raise Bunny::ConnectionError, 'Connection socket has not been created!' if @socket.nil?
        if @read_write_timeout
          Bunny::Timer.timeout(@read_write_timeout, Qrack::ClientTimeout) do
            @socket.__send__(cmd, *args)
          end
        else
          @socket.__send__(cmd, *args)
        end
      rescue Errno::EPIPE, Errno::EAGAIN, Qrack::ClientTimeout, IOError => e
        # Ensure we close the socket when we are down to prevent further
        # attempts to write to a closed socket
        close_socket
        raise Bunny::ServerDownError, e.message
      end
    end

    def socket
      return @socket if @socket and (@status == :connected) and not @socket.closed?

      begin
        @socket = Bunny::Timer.timeout(@connect_timeout, ConnectionTimeout) do
          TCPSocket.new(host, port)
        end

        if Socket.constants.include?('TCP_NODELAY') || Socket.constants.include?(:TCP_NODELAY)
          @socket.setsockopt Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1
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

  end # Session

  # backwards compatibility
  Client = Session
end
