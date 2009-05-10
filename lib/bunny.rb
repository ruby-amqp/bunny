$:.unshift File.expand_path(File.dirname(__FILE__))

# Ruby standard libraries
%w[socket thread timeout].each do |file|
	require file
end

require 'bunny/client'
require 'bunny/exchange'
require 'bunny/queue'

require 'bunny/protocol/spec'
require 'bunny/protocol/protocol'

require 'bunny/transport/buffer'
require 'bunny/transport/frame'

module Bunny
	
	include Protocol
	include Transport

	class ProtocolError < StandardError; end
	class ServerDownError < StandardError; end
	class BufferOverflowError < StandardError; end
  class InvalidTypeError < StandardError; end
	class ConnectionError < StandardError; end
	class MessageError < StandardError; end
	
	VERSION = '0.3.0'
	
	# Returns the Bunny version number

	def self.version
		VERSION
	end

end