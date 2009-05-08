module Bunny
  class Client
    CONNECT_TIMEOUT = 1.0
    RETRY_DELAY     = 10.0

    attr_reader   :status, :host, :vhost, :port
    attr_accessor :channel, :logging, :exchanges, :queues, :ticket

    def initialize(opts = {})
			@host = opts[:host] || 'localhost'
			@port = opts[:port] || Protocol::PORT
      @user   = opts[:user]  || 'guest'
      @pass   = opts[:pass]  || 'guest'
      @vhost  = opts[:vhost] || '/'
			@logging = opts[:logging] || false
      @insist = opts[:insist]
      @status = :not_connected
    end

		def exchange(name, opts = {})
			exchanges[name] ||= Bunny::Exchange.new(self, name, opts)
		end

		def exchanges
			@exchanges ||= {}
		end
		
		def queue(name, opts = {})
	    queues[name] ||= Bunny::Queue.new(self, name, opts)
	  end
		
		def queues
			@queues ||= {}
		end

    def send_frame(*args)
      args.each do |data|
        data.ticket  = ticket if ticket and data.respond_to?(:ticket=)
        data         = data.to_frame(channel) unless data.is_a?(Transport::Frame)
        data.channel = channel

        log :send, data
        write(data.to_s)
      end
      nil
    end

    def next_frame
      frame = Transport::Frame.parse(buffer)
      log :received, frame
      frame
    end

    def next_method
      next_payload
    end

    def next_payload
      frame = next_frame
      frame.payload
    end

    def close
      send_frame(
        Protocol::Channel::Close.new(:reply_code => 200, :reply_text => 'bye', :method_id => 0, :class_id => 0)
      )
      raise Bunny::ProtocolError, "Error closing channel #{channel}" unless next_method.is_a?(Protocol::Channel::CloseOk)

      self.channel = 0
      send_frame(
        Protocol::Connection::Close.new(:reply_code => 200, :reply_text => 'Goodbye', :class_id => 0, :method_id => 0)
      )
      raise Bunny::ProtocolError, "Error closing connection" unless next_method.is_a?(Protocol::Connection::CloseOk)

      close_socket
    end

		alias stop close

    def read(*args)
      send_command(:read, *args)
    end

    def write(*args)
      send_command(:write, *args)
    end

		def start_session
      @channel = 0
      write(Protocol::HEADER)
      write([1, 1, Protocol::VERSION_MAJOR, Protocol::VERSION_MINOR].pack('C4'))
      raise Bunny::ProtocolError, 'Connection initiation failed' unless next_method.is_a?(Protocol::Connection::Start)

      send_frame(
        Protocol::Connection::StartOk.new(
          {:platform => 'Ruby', :product => 'Bunny', :information => 'http://github.com/celldee/bunny', :version => VERSION},
          'AMQPLAIN',
          {:LOGIN => @user, :PASSWORD => @pass},
          'en_US'
        )
      )
			
			method = next_method
			raise Bunny::ProtocolError, "Connection failed - user: #{@user}, pass: #{@pass}" if method.nil?

      if method.is_a?(Protocol::Connection::Tune)
        send_frame(
          Protocol::Connection::TuneOk.new( :channel_max => 0, :frame_max => 131072, :heartbeat => 0)
        )
      end

      send_frame(
        Protocol::Connection::Open.new(:virtual_host => @vhost, :capabilities => '', :insist => @insist)
      )
      raise Bunny::ProtocolError, 'Cannot open connection' unless next_method.is_a?(Protocol::Connection::OpenOk)

      @channel = 1
      send_frame(Protocol::Channel::Open.new)
      raise Bunny::ProtocolError, "Cannot open channel #{channel}" unless next_method.is_a?(Protocol::Channel::OpenOk)

      send_frame(
        Protocol::Access::Request.new(:realm => '/data', :read => true, :write => true, :active => true, :passive => true)
      )
      method = next_method
      raise Bunny::ProtocolError, 'Access denied' unless method.is_a?(Protocol::Access::RequestOk)
      self.ticket = method.ticket

			# return status
			status
    end

		alias start start_session

  private

    def buffer
      @buffer ||= Transport::Buffer.new(self)
    end

    def send_command(cmd, *args)
      begin
        socket.__send__(cmd, *args)
      rescue Errno::EPIPE, IOError => e
        raise Bunny::ServerDownError, e.message
      end
    end

    def socket
      return @socket if @socket and not @socket.closed?

      begin
        # Attempt to connect.
        @socket = timeout(CONNECT_TIMEOUT) do
          TCPSocket.new(host, port)
        end

        if Socket.constants.include? 'TCP_NODELAY'
          @socket.setsockopt Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1
        end
        @status   = :connected
      rescue SocketError, SystemCallError, IOError, Timeout::Error => e
        raise Bunny::ServerDownError, e.message
      end

      @socket
    end

    def close_socket(reason=nil)
      # Close the socket. The server is not considered dead.
      @socket.close if @socket and not @socket.closed?
      @socket   = nil
      @status   = :not_connected
    end

    def log(*args)
      return unless logging
      require 'pp'
      pp args
	    puts
    end

  end
end