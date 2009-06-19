$:.unshift File.expand_path(File.dirname(__FILE__))

# Ruby standard libraries
%w[socket thread timeout logger].each do |file|
	require file
end

module Bunny

	class ProtocolError < StandardError; end
	class ServerDownError < StandardError; end
	class ConnectionError < StandardError; end
	class MessageError < StandardError; end
	
	VERSION = '0.4.3'
	
	# Returns the Bunny version number

	def self.version
		VERSION
	end
	
	# Instantiates new Bunny::Client

	def self.new(opts = {})
		# Set up Bunny according to AMQP spec version required
		spec_version = opts[:spec] || '08'
		setup(spec_version)
		
		Bunny::Client.new(opts)
	end
	
	# Runs a code block using a short-lived connection

  def self.run(opts = {}, &block)
    raise ArgumentError, 'Bunny#run requires a block' unless block

		# Set up Bunny according to AMQP spec version required
		spec_version = opts[:spec] || '08'
		setup(spec_version)
		
    client = Bunny::Client.new(opts)
    client.start

    block.call(client)

    client.stop

		# Return success
		:run_ok
  end

	private
	
	def self.setup(version)

		if version == '08'
			# AMQP 0-8 specification
			require 'qrack/qrack08'
			require 'bunny/client08'
			require 'bunny/exchange08'
			require 'bunny/queue08'
		else
			# AMQP 0-9-1 specification
			require 'qrack/qrack091'
			require 'bunny/client091'
			require 'bunny/exchange091'
			require 'bunny/queue091'
		end			
		
		include Qrack
	end

end
