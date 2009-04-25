class Bunny
	class Queue
		
		include AMQP
		
	  attr_reader :name, :client
	  attr_accessor :delivery_tag

	  def initialize(client, name, opts = {})
			# check connection to server
			raise 'Not connected to server' if client.status == NOT_CONNECTED
			
	    @client = client
	    @opts   = opts
	    @name   = name
	    client.send_frame(
	      Protocol::Queue::Declare.new({ :queue => name, :nowait => false }.merge(opts))
	    )
	
			raise ProtocolError, "Error declaring queue #{name}" unless client.next_method.is_a?(Protocol::Queue::DeclareOk)
	  end

	  def pop(opts = {})
	    self.delivery_tag = nil
	
			# do we want the header?
			hdr = opts.delete(:header)
			
	    client.send_frame(
	      Protocol::Basic::Get.new({ :queue => name,
																	 :consumer_tag => name,
																	 :no_ack => !opts.delete(:ack),
																	 :nowait => true }.merge(opts))
	    )
	
			method = client.next_method
			
			if method.is_a?(Protocol::Basic::GetEmpty) then
				return QUEUE_EMPTY
			elsif	!method.is_a?(Protocol::Basic::GetOk)
				raise ProtocolError, "Error getting message from queue #{name}"
			end

	    self.delivery_tag = method.delivery_tag

			return QUEUE_EMPTY unless !self.delivery_tag.nil?
			
	    header = client.next_payload
	    msg    = client.next_payload
	    raise 'unexpected length' if msg.length < header.size

			hdr ? {:header => header, :payload => msg} : msg
			
	  end

	  def ack
	    client.send_frame(
	      Protocol::Basic::Ack.new(:delivery_tag => delivery_tag)
	    )
	  end

	  def publish(data, opts = {})
	    exchange.publish(data, opts)
	  end

	  def message_count
	    status.first
	  end

	  def consumer_count
	    status.last
	  end
  
	  def status(opts = {}, &blk)
	    client.send_frame(
	      Protocol::Queue::Declare.new({ :queue => name, :passive => true }.merge(opts))
	    )
	    method = client.next_method
	    [method.message_count, method.consumer_count]
	  end

	  def bind(exchange, opts = {})
	    exchange           = exchange.respond_to?(:name) ? exchange.name : exchange
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
	  end

	  def delete(opts = {})
	    client.send_frame(
	      Protocol::Queue::Delete.new({ :queue => name, :nowait => false }.merge(opts))
	    )
	
			raise ProtocolError,
				"Error deleting queue #{name}" unless
				client.next_method.is_a?(Protocol::Queue::DeleteOk)
	
			client.queues.delete(name)
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