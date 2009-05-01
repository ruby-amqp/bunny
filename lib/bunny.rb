$:.unshift File.expand_path(File.dirname(__FILE__))

# Ruby standard libraries
%w[socket thread timeout].each do |file|
	require file
end

# AMQP protocol and transport
%w[spec protocol buffer frame].each do |file|
	require 'engineroom/' + file
end

# Bunny API 
%w[client exchange header queue].each do |file|
	require 'bunny/' + file
end

# Error and return message definitions
require 'api_messages'

class Bunny
	include Protocol
	include Transport
	include API
	
	VERSION = '0.2.0'

	attr_reader :client

	def initialize(opts = {})
		@client = API::Client.new(opts)
  end

	def self.version
		VERSION
	end

	def logging=(bool)
		client.logging = bool
	end
	
	def logging
		client.logging
	end

	def start
		client.start_session
	end

	def status
		client.status
	end
	
	def exchange(name, opts = {})
		client.exchanges[name] ||= API::Exchange.new(client, name, opts)
	end
  
  def queue(name, opts = {})
    client.queues[name] ||= API::Queue.new(client, name, opts)
  end

  def stop
    client.close
  end

  def queues
    client.queues ||= {}
  end

  def exchanges
    client.exchanges ||= {}
  end
	
	def host
		client.host
	end
	
	def vhost
		client.vhost
	end
	
	def port
		client.port
	end
	
end