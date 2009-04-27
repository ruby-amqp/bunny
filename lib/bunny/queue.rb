class Bunny
	class Queue
		
		include AMQP
		
	  attr_reader :name, :client
	  attr_accessor :delivery_tag

	  def initialize(client, name, opts = {})
			# check connection to server
			raise ConnectionError, 'Not connected to server' if client.status == NOT_CONNECTED
			
	    @client = client
	    @opts   = opts
	    @name   = name
	
			# ignore the :nowait option if passed, otherwise program will hang waiting for a
			# response that will not be sent by the server
			opts.delete(:nowait)
			
	    client.send_frame(
	      Protocol::Queue::Declare.new({ :queue => name, :nowait => false }.merge(opts))
	    )
	
			raise ProtocolError, "Error declaring queue #{name}" unless client.next_method.is_a?(Protocol::Queue::DeclareOk)
	  end
	
		def ack
      client.send_frame(
        Protocol::Basic::Ack.new(:delivery_tag => delivery_tag)
      )

			# reset delivery tag
			self.delivery_tag = nil
    end

	  def pop(opts = {})
			
			# do we want the message header?
			hdr = opts.delete(:header)
			
			# do we want to have to provide an acknowledgement?
			ack = opts.delete(:ack)
			
	    client.send_frame(
	      Protocol::Basic::Get.new({ :queue => name,
																	 :consumer_tag => name,
																	 :no_ack => !ack,
																	 :nowait => true }.merge(opts))
	    )
	
			method = client.next_method
			
			if method.is_a?(Protocol::Basic::GetEmpty) then
				return QUEUE_EMPTY
			elsif	!method.is_a?(Protocol::Basic::GetOk)
				raise ProtocolError, "Error getting message from queue #{name}"
			end
			
			# get delivery tag to use for acknowledge
			self.delivery_tag = method.delivery_tag if ack
			
	    header = client.next_payload
	    msg    = client.next_payload
	    raise MessageError, 'unexpected length' if msg.length < header.size

			hdr ? {:header => header, :payload => msg} : msg
			
	  end

	  def publish(data, opts = {})
	    exchange.publish(data, opts)
	  end

	  def message_count
	    s = status
			s[:message_count]
	  end

	  def consumer_count
	    s = status
			s[:consumer_count]
	  end
  
	  def status(opts = {})
	    client.send_frame(
	      Protocol::Queue::Declare.new({ :queue => name, :passive => true }.merge(opts))
	    )
	    method = client.next_method
	    {:message_count => method.message_count, :consumer_count => method.consumer_count}
	  end
	
		def subscribe(opts = {})
			consumer_tag = opts[:consumer_tag] || name
			
			# ignore the :nowait option if passed, otherwise program will not wait for a
			# message to get to the server causing an error
			opts.delete(:nowait)
			
			# do we want the message header?
			hdr = opts.delete(:header)
			
			# do we want to have to provide an acknowledgement?
			ack = opts.delete(:ack)
			
			client.send_frame(
				Protocol::Basic::Consume.new({ :queue => name,
																	 		 :consumer_tag => consumer_tag,
																	 		 :no_ack => !ack,
																	 		 :nowait => false }.merge(opts))
			)
			
			raise ProtocolError,
				"Error subscribing to queue #{name}" unless
				client.next_method.is_a?(Protocol::Basic::ConsumeOk)
			
			method = client.next_method
			
			# get delivery tag to use for acknowledge
			self.delivery_tag = method.delivery_tag if ack
			
			header = client.next_payload
	    msg    = client.next_payload
	    raise MessageError, 'unexpected length' if msg.length < header.size

			hdr ? {:header => header, :payload => msg} : msg
		end

	  def bind(exchange, opts = {})
	    exchange           = exchange.respond_to?(:name) ? exchange.name : exchange
	
			# ignore the :nowait option if passed, otherwise program will hang waiting for a
			# response that will not be sent by the server
			opts.delete(:nowait)
			
	    bindings[exchange] = opts
	    client.send_frame(
	      Protocol::Queue::Bind.new({ :queue => name,
		 																:exchange => exchange,
		 																:routing_key => opts.delete(:key),
		 																:nowait => false }.merge(opts))
	    )
	
			raise ProtocolError,
				"Error binding queue #{name}" unless
				client.next_method.is_a?(Protocol::Queue::BindOk)
				
			# return message
			BIND_SUCCEEDED
	  end

	  def unbind(exchange, opts = {})
	    exchange = exchange.respond_to?(:name) ? exchange.name : exchange
	    bindings.delete(exchange)

	    client.send_frame(
	      Protocol::Queue::Unbind.new({ :queue => name,
		 																	:exchange => exchange,
		 																	:routing_key => opts.delete(:key),
		 																	:nowait => false }.merge(opts)
	      )
	    )
	
			raise ProtocolError,
				"Error unbinding queue #{name}" unless
				client.next_method.is_a?(Protocol::Queue::UnbindOk)
				
			# return message
			UNBIND_SUCCEEDED
	  end

	  def delete(opts = {})
			# ignore the :nowait option if passed, otherwise program will hang waiting for a
			# response that will not be sent by the server
			opts.delete(:nowait)
			
	    client.send_frame(
	      Protocol::Queue::Delete.new({ :queue => name, :nowait => false }.merge(opts))
	    )
	
			raise ProtocolError,
				"Error deleting queue #{name}" unless
				client.next_method.is_a?(Protocol::Queue::DeleteOk)
	
			client.queues.delete(name)
			
			# return confirmation
			QUEUE_DELETED
	  end

	private
	  def exchange
	    @exchange ||= Bunny::Exchange.new(client, '', {:type => :direct, :key => name})
	  end

	  def bindings
	    @bindings ||= {}
	  end
	end
	
end