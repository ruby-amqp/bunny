module AMQP
	%w[ spec buffer protocol frame client ].each do |file|
    require "amqp/#{file}"
  end

	# constants
	CONNECTED = 'CONNECTED'
	NOT_CONNECTED = 'NOT CONNECTED'
	QUEUE_EMPTY = 'QUEUE EMPTY'

	# specific error definitions
	class ProtocolError < StandardError; end
	class ServerDownError < StandardError; end
	class BufferOverflowError < StandardError; end
  class InvalidTypeError < StandardError; end
	class ConnectionError < StandardError; end
	class MessageError < StandardError; end
end