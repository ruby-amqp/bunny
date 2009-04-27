module AMQP
	%w[ spec buffer protocol frame client ].each do |file|
    require "amqp/#{file}"
  end

	# return messages
	CONNECTED = 'CONNECTED'
	NOT_CONNECTED = 'NOT CONNECTED'
	QUEUE_EMPTY = 'QUEUE EMPTY'
	QUEUE_DELETED = 'QUEUE DELETED'
	EXCHANGE_DELETED = 'EXCHANGE DELETED'
	BIND_SUCCEEDED = 'BIND SUCCEEDED'
	UNBIND_SUCCEEDED = 'UNBIND SUCCEEDED'

	# specific error definitions
	class ProtocolError < StandardError; end
	class ServerDownError < StandardError; end
	class BufferOverflowError < StandardError; end
  class InvalidTypeError < StandardError; end
	class ConnectionError < StandardError; end
	class MessageError < StandardError; end
end