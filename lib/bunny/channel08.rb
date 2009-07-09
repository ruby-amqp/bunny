module Bunny
	class Channel
		attr_accessor :number, :active
		attr_reader :client
		
		def initialize(client, zero = false)
			@client = client
			zero ? @number = 0 : @number = client.channels.size
			@active = false
			client.channels[@number] ||= self
		end
		
		def open
			client.channel = self
			client.send_frame(Qrack::Protocol08::Channel::Open.new)
      raise Bunny::ProtocolError, "Cannot open channel #{number}" unless client.next_method.is_a?(Qrack::Protocol08::Channel::OpenOk)

			active = true
		end
		
		def close
			client.channel = self
			client.send_frame(
	      Qrack::Protocol08::Channel::Close.new(:reply_code => 200, :reply_text => 'bye', :method_id => 0, :class_id => 0)
	    )
	    raise Bunny::ProtocolError, "Error closing channel #{number}" unless client.next_method.is_a?(Qrack::Protocol08::Channel::CloseOk)
	
			active = false
		end
		
		def open?
			active
		end
		
	end
end