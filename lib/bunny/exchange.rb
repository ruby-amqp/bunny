module Bunny
	class Exchange
	
	  attr_reader :client, :type, :name, :opts, :key

	  def initialize(client, name, opts = {})
			# check connection to server
			raise Bunny::ConnectionError, 'Not connected to server' if client.status == :not_connected
		
	    @client, @name, @opts = client, name, opts
	
			# set up the exchange type catering for default names
			if name.match(/^amq\./)
				new_type = name.sub(/amq\./, '')
				# handle 'amq.match' default
				new_type = 'headers' if new_type == 'match'
				@type = new_type.to_sym
			else
				@type = opts[:type] || :direct
			end
			
	    @key = opts[:key]
			@client.exchanges[@name] ||= self
			
			# ignore the :nowait option if passed, otherwise program will hang waiting for a
			# response that will not be sent by the server
			opts.delete(:nowait)
			
	    unless name == "amq.#{type}" or name == ''
	      client.send_frame(
	        Protocol::Exchange::Declare.new(
	          { :exchange => name, :type => type, :nowait => false }.merge(opts)
	        )
	      )

				raise Bunny::ProtocolError,
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
	    out << Transport::Frame::Body.new(data)

	    client.send_frame(*out)
	  end

	  def delete(opts = {})
			# ignore the :nowait option if passed, otherwise program will hang waiting for a
			# response that will not be sent by the server
			opts.delete(:nowait)
			
	    client.send_frame(
	      Protocol::Exchange::Delete.new({ :exchange => name, :nowait => false }.merge(opts))
	    )

			raise Bunny::ProtocolError,
				"Error deleting exchange #{name}" unless
				client.next_method.is_a?(Protocol::Exchange::DeleteOk)

			client.exchanges.delete(name)
			
			# return confirmation
			:exchange_deleted
	  end

	end
	
end