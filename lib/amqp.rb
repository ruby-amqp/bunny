module AMQP
	%w[ spec buffer protocol frame client ].each do |file|
    require "amqp/#{file}"
  end

	# constants
	CONNECTED = 'CONNECTED'
	NOT_CONNECTED = 'NOT CONNECTED'
	QUEUE_EMPTY = 'QUEUE EMPTY'

	# specific error definitions
	class ProtocolError   < StandardError; end
	class ServerDown      < StandardError; end
	class Overflow < StandardError; end
  class InvalidType < StandardError; end
end