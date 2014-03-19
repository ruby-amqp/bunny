#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'bunny'

conn = Bunny.new(:heartbeat_interval => 8)
conn.start

ch = conn.create_channel
x  = ch.topic("bunny.examples.recovery.topic", :durable => false)
q  = ch.queue("bunny.examples.recovery.client_named_queue1", :durable => false)

q.bind(x, :routing_key => "abc").bind(x, :routing_key => "def")

q.subscribe do |delivery_info, metadata, payload|
  puts "Consumed #{payload}"
end

loop do
  sleep 2
  data = rand.to_s
  rk   = ["abc", "def"].sample

  begin
    x.publish(data, :routing_key => rk)
    puts "Published #{data}, routing key: #{rk}"
  # happens when a message is published before the connection
  # is recovered
  rescue Exception => e
  end
end
