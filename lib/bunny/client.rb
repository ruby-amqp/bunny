module Bunny
	
=begin rdoc

=== DESCRIPTION:

The Client class provides the major Bunny API methods.

=end

  class Client < Qrack::Client
    CONNECT_TIMEOUT = 1.0
    RETRY_DELAY     = 10.0

    attr_reader   :status, :host, :vhost, :port
    attr_accessor :channel, :logging, :exchanges, :queues, :ticket

=begin rdoc

=== DESCRIPTION:

Sets up a Bunny::Client object ready for connection to a broker/server. _Client_._status_ is set to
<tt>:not_connected</tt>.

==== OPTIONS:

* <tt>:host => '_hostname_' (default = 'localhost')</tt>
* <tt>:port => _portno_ (default = 5672)</tt>
* <tt>:vhost => '_vhostname_' (default = '/')</tt>
* <tt>:user => '_username_' (default = 'guest')</tt>
* <tt>:pass => '_password_' (default = 'guest')</tt>
* <tt>:logging => true or false (_default_)</tt> - If set to _true_, session information is sent
  to STDOUT.
* <tt>:insist => true or false (_default_)</tt> - In a configuration with multiple load-sharing
  servers, the server may respond to a Connection.Open method with a Connection.Redirect. The insist
  option, if set to _true_, tells the server that the client is insisting on a connection to the
  specified server.

=end

    def initialize(opts = {})
			@host = opts[:host] || 'localhost'
			@port = opts[:port] || Qrack::Protocol::PORT
      @user   = opts[:user]  || 'guest'
      @pass   = opts[:pass]  || 'guest'
      @vhost  = opts[:vhost] || '/'
			@logging = opts[:logging] || false
      @insist = opts[:insist]
      @status = :not_connected
    end

=begin rdoc

=== DESCRIPTION:

Declares an exchange to the broker/server. If the exchange does not exist, a new one is created
using the arguments passed in. If the exchange already exists, a reference to it is created, provided
that the arguments passed in do not conflict with the existing attributes of the exchange. If an error
occurs a _Bunny_::_ProtocolError_ is raised.

==== OPTIONS:

* <tt>:type => one of :direct (_default_), :fanout, :topic, :headers</tt>
* <tt>:passive => true or false</tt> - If set to _true_, the server will not create the exchange.
  The client can use this to check whether an exchange exists without modifying the server state.
* <tt>:durable => true or false (_default_)</tt> - If set to _true_ when creating a new exchange, the exchange
  will be marked as durable. Durable exchanges remain active when a server restarts. Non-durable
  exchanges (transient exchanges) are purged if/when a server restarts.
* <tt>:auto_delete => true or false (_default_)</tt> - If set to _true_, the exchange is deleted
  when all queues have finished using it.
* <tt>:nowait => true or false (_default_)</tt> - Ignored by Bunny, always _false_.

==== RETURNS:

Exchange

=end

		def exchange(name, opts = {})
			exchanges[name] ||= Bunny::Exchange.new(self, name, opts)
		end

=begin rdoc

=== DESCRIPTION:

Returns hash of exchanges declared by Bunny.

=end

		def exchanges
			@exchanges ||= {}
		end

=begin rdoc

=== DESCRIPTION:

Declares a queue to the broker/server. If the queue does not exist, a new one is created
using the arguments passed in. If the queue already exists, a reference to it is created, provided
that the arguments passed in do not conflict with the existing attributes of the queue. If an error
occurs a _Bunny_::_ProtocolError_ is raised.

==== OPTIONS:

* <tt>:passive => true or false (_default_)</tt> - If set to _true_, the server will not create
  the queue. The client can use this to check whether a queue exists without modifying the server
  state.
* <tt>:durable => true or false (_default_)</tt> - 	If set to _true_ when creating a new queue, the
  queue will be marked as durable. Durable queues remain active when a server restarts. Non-durable
  queues (transient queues) are purged if/when a server restarts. Note that durable queues do not
  necessarily hold persistent messages, although it does not make sense to send persistent messages
  to a transient queue.
* <tt>:exclusive => true or false (_default_)</tt> - If set to _true_, requests an exclusive queue.
  Exclusive queues may only be consumed from by the current connection. Setting the 'exclusive'
  flag always implies 'auto-delete'.
* <tt>:auto_delete => true or false (_default_)</tt> - 	If set to _true_, the queue is deleted
  when all consumers have finished	using it. Last consumer can be cancelled either explicitly
  or because its channel is closed. If there has never been a consumer on the queue, it is not
  deleted.
* <tt>:nowait => true or false (_default_)</tt> - Ignored by Bunny, always _false_.

==== RETURNS:

Queue

=end
		
		def queue(name = nil, opts = {})
      if name.is_a?(Hash)
        opts = name
        name = nil
      end

      return queues[name] if queues.has_key?(name)

      queue = Bunny::Queue.new(self, name, opts)
      queues[queue.name] = queue
	  end
	
=begin rdoc

=== DESCRIPTION:

Returns hash of queues declared by Bunny.

=end
		
		def queues
			@queues ||= {}
		end

    def send_frame(*args)
      args.each do |data|
        data.ticket  = ticket if ticket and data.respond_to?(:ticket=)
        data         = data.to_frame(channel) unless data.is_a?(Qrack::Transport::Frame)
        data.channel = channel

        log :send, data
        write(data.to_s)
      end
      nil
    end

    def next_frame
      frame = Qrack::Transport::Frame.parse(buffer)
      log :received, frame
      frame
    end

    def next_method
      next_payload
    end

    def next_payload
      frame = next_frame
      frame and frame.payload
    end

=begin rdoc

=== DESCRIPTION:

Closes the current communication channel and connection. If an error occurs a
_Bunny_::_ProtocolError_ is raised. If successful, _Client_._status_ is set to <tt>:not_connected</tt>.

==== RETURNS:

<tt>:not_connected</tt> if successful.

=end

    def close
      send_frame(
        Qrack::Protocol::Channel::Close.new(:reply_code => 200, :reply_text => 'bye', :method_id => 0, :class_id => 0)
      )
      raise Bunny::ProtocolError, "Error closing channel #{channel}" unless next_method.is_a?(Qrack::Protocol::Channel::CloseOk)

      self.channel = 0
      send_frame(
        Qrack::Protocol::Connection::Close.new(:reply_code => 200, :reply_text => 'Goodbye', :class_id => 0, :method_id => 0)
      )
      raise Bunny::ProtocolError, "Error closing connection" unless next_method.is_a?(Qrack::Protocol::Connection::CloseOk)

      close_socket
    end

		alias stop close

    def read(*args)
      send_command(:read, *args)
    end

    def write(*args)
      send_command(:write, *args)
    end

=begin rdoc

=== DESCRIPTION:

Opens a communication channel and starts a connection. If an error occurs, a
_Bunny_::_ProtocolError_ is raised. If successful, _Client_._status_ is set to <tt>:connected</tt>.

==== RETURNS:

<tt>:connected</tt> if successful.

=end
		
		def start_session
      loop do
        @channel = 0
        write(Qrack::Protocol::HEADER)
        write([1, 1, Qrack::Protocol::VERSION_MAJOR, Qrack::Protocol::VERSION_MINOR].pack('C4'))
        raise Bunny::ProtocolError, 'Connection initiation failed' unless next_method.is_a?(Qrack::Protocol::Connection::Start)

        send_frame(
          Qrack::Protocol::Connection::StartOk.new(
            {:platform => 'Ruby', :product => 'Bunny', :information => 'http://github.com/celldee/bunny', :version => VERSION},
            'AMQPLAIN',
            {:LOGIN => @user, :PASSWORD => @pass},
            'en_US'
          )
        )

        method = next_method
        raise Bunny::ProtocolError, "Connection failed - user: #{@user}, pass: #{@pass}" if method.nil?

        if method.is_a?(Qrack::Protocol::Connection::Tune)
          send_frame(
            Qrack::Protocol::Connection::TuneOk.new( :channel_max => 0, :frame_max => 131072, :heartbeat => 0)
          )
        end

        send_frame(
          Qrack::Protocol::Connection::Open.new(:virtual_host => @vhost, :capabilities => '', :insist => @insist)
        )

        case method = next_method
        when Qrack::Protocol::Connection::OpenOk
          break
        when Qrack::Protocol::Connection::Redirect
          @host, @port = method.host.split(':')
          close_socket
        else
          raise Bunny::ProtocolError, 'Cannot open connection'
        end
      end

      @channel = 1
      send_frame(Qrack::Protocol::Channel::Open.new)
      raise Bunny::ProtocolError, "Cannot open channel #{channel}" unless next_method.is_a?(Qrack::Protocol::Channel::OpenOk)

      send_frame(
        Qrack::Protocol::Access::Request.new(:realm => '/data', :read => true, :write => true, :active => true, :passive => true)
      )
      method = next_method
      raise Bunny::ProtocolError, 'Access denied' unless method.is_a?(Qrack::Protocol::Access::RequestOk)
      self.ticket = method.ticket

			# return status
			status
    end

		alias start start_session
		
=begin rdoc

=== DESCRIPTION:

Asks the broker to redeliver all unacknowledged messages on a specifieid channel. Zero or
more messages may be redelivered.

==== Options:

* <tt>:requeue => true or false (_default_)</tt> - If set to _false_, the message will be
redelivered to the original recipient. If set to _true_, the server will attempt to requeue
the message, potentially then delivering it to an alternative subscriber.

=end

		def recover(opts = {})

	    send_frame(
	      Qrack::Protocol::Basic::Recover.new({ :requeue => false }.merge(opts))
	    )

	  end

  private

    def buffer
      @buffer ||= Qrack::Transport::Buffer.new(self)
    end

    def send_command(cmd, *args)
      begin
        socket.__send__(cmd, *args)
      rescue Errno::EPIPE, IOError => e
        raise Bunny::ServerDownError, e.message
      end
    end

    def socket
      return @socket if @socket and (@status == :connected) and not @socket.closed?

      begin
        @status = :not_connected
   
        # Attempt to connect.
        @socket = timeout(CONNECT_TIMEOUT) do
          TCPSocket.new(host, port)
        end

        if Socket.constants.include? 'TCP_NODELAY'
          @socket.setsockopt Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1
        end
        @status   = :connected
      rescue => e
        @status = :not_connected
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
