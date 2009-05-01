module API
	class Header
	
		attr_reader :client
	
	  def initialize(client, header_obj)
	    @client = client
	    @header = header_obj
	  end

	  # Acknowledges the receipt of this message with the server.
	  def ack
	    client.send(Protocol::Basic::Ack.new(:delivery_tag => properties[:delivery_tag]))
	  end

	  # Reject this message (XXX currently unimplemented in rabbitmq)
	  # * :requeue => true | false (default false)
	  def reject(opts = {})
	    client.send(Protocol::Basic::Reject.new(opts.merge(:delivery_tag => properties[:delivery_tag])))
	  end

	  def method_missing(meth, *args, &blk)
	    @header.send(meth, *args, &blk)
	  end

	  def inspect
	    @header.inspect
	  end
	end
end