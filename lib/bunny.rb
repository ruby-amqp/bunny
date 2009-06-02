$:.unshift File.expand_path(File.dirname(__FILE__))

# Ruby standard libraries
%w[socket thread timeout].each do |file|
	require file
end

require 'qrack/qrack'

require 'bunny/client'
require 'bunny/exchange'
require 'bunny/queue'

module Bunny
	
	include Qrack

	class ProtocolError < StandardError; end
	class ServerDownError < StandardError; end
	class ConnectionError < StandardError; end
	class MessageError < StandardError; end
	
	VERSION = '0.4.2'
	
	# Returns the Bunny version number

	def self.version
		VERSION
	end
	
	# Instantiates new Bunny::Client
	
	def self.new(opts = {})
		Bunny::Client.new(opts)
	end

  def self.open(opts = {}, &block)
    raise ArgumentError, 'open requires a block' unless block

    client = Bunny::Client.new(opts)
    client.start

    block.call(client)

    client.stop
  end

end
