$:.unshift File.expand_path(File.dirname(__FILE__))

%w[socket thread timeout amqp].each do |file|
	require file
end

%w[ exchange queue header ].each do |file|
  require "bunny/#{file}"
end

class Bunny
	
	attr_reader :client

	def initialize(opts = {})
		@client = AMQP::Client.new(opts)
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
		client.exchanges[name] ||= Exchange.new(client, name, opts)
	end
  
  def queue(name, opts = {})
    client.queues[name] ||= Queue.new(client, name, opts)
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