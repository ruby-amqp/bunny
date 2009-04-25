class Bunny
	class Exchange
	
		include AMQP
	
	  attr_reader :client, :type, :name, :opts, :key

	  def initialize(client, name, opts = {})
			# check connection to server
			raise 'Not connected to server' if client.status == NOT_CONNECTED
		
	    @client, @name, @opts = client, name, opts
			@type = opts[:type] || :direct
			opts.delete(:type) unless opts[:type].nil?
	    @key = opts[:key]
			@client.exchanges[@name] ||= self
		
	    unless name == "amq.#{type}" or name == ''
	      client.send_frame(
	        Protocol::Exchange::Declare.new(
	          { :exchange => name, :type => type, :nowait => false }.merge(opts)
	        )
	      )

				raise ProtocolError,
					"Error declaring exchange #{name}: type = #{type}" unless
					client.next_method.is_a?(Protocol::Exchange::DeclareOk)
	    end
	  end

	  def publish(data, opts = {})
	    out = []

	    out << Protocol::Basic::Publish.new(
	      { :exchange => name, :routing_key => opts.delete(:key) || key }.merge(opts)
	    )
	    data = data.to_s
	    out << Protocol::Header.new(
	      Protocol::Basic,
	      data.length, {
	        :content_type  => 'application/octet-stream',
	        :delivery_mode => (opts.delete(:persistent) ? 2 : 1),
	        :priority      => 0 
	      }.merge(opts)
	    )
	    out << Frame::Body.new(data)

	    client.send_frame(*out)
	  end

	  def delete(opts = {})	
	    client.send_frame(
	      Protocol::Exchange::Delete.new({ :exchange => name, :nowait => false }.merge(opts))
	    )

			raise ProtocolError,
				"Error deleting exchange #{name}" unless
				client.next_method.is_a?(Protocol::Exchange::DeleteOk)

			client.exchanges.delete(name)
	  end

	end
	
end