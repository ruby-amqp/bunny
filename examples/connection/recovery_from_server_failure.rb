#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'bunny'

class RMQ
  def connect
    Bunny.new(
      :user     => "bunny_gem",
      :password => "bunny_password",
      :vhost    => "bunny_testbed",
    ).tap { |b| b.start }
  end

  def start
    `rabbitmq-server -detached` if down?
  end

  def stop
    `rabbitmqctl stop` if up?
  end

  def stop_in(seconds)
    Thread.new {
      sleep seconds
      stop
    }
  end

  def start_in(seconds)
    Thread.new {
      sleep seconds
      start
    }
  end
  alias_method :restart_in, :start_in

  def down?
    `rabbitmqctl status 2>&1`.index(/not.found|nodedown/)
  end

  def up?
    !down?
  end
end

@rmq = RMQ.new

@rmq.start
@rmq.stop_in(2)
@rmq.restart_in(5)
@rmq.stop_in(6)
@rmq.restart_in(10)

def connection
  @connection ||= Thread.new { @rmq.connect }.value
end

def channel
  @channel ||= connection.create_channel
end

def queue
  @queue ||= begin
    q = channel.queue("", :auto_delete => true)
    q.subscribe { |delivery_info, properties, payload|
      puts "Received '#{payload}' at #{Time.now}"
    }
    q
  end
end

unsent_messages = []

while connection
  message = Time.now.to_s

  if connection.open?
    queue.publish(message, :routing_key => queue.name)
    if @connection_restored
      puts "Connection restored"
      unsent_messages.each do |m|
        queue.publish(m, :routing_key => queue.name) &&
        unsent_messages.delete(m)
      end
    end
  else
    puts "Bunny connection closed"
    unsent_messages << message
    begin
      @connection = nil
      connection.start && @connection_restored = true
    rescue
      @channel = nil
      @queue = nil
      puts "Unsent messages: #{unsent_messages}"

      puts "Retrying RabbitMQ connection"
      sleep 0.5
      retry
    end
  end

  sleep 0.5
end
