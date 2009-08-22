module Qrack
	# Channel ancestor class
	class Channel
		
		attr_accessor :number, :active
		attr_reader :client
		
		def initialize(client)
			@client = client
			@number = client.channels.size
			@active = false
			client.channels[@number] = self
		end
		
	end
	
end