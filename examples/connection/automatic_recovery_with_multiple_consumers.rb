#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'bunny'

conn = Bunny.new(:heartbeat_interval => 8)
conn.start

ch1 = conn.create_channel
x1  = ch1.topic("bunny.examples.recovery.e1", :durable => false)
q1  = ch1.queue("bunny.examples.recovery.q1", :durable => false)

q1.bind(x1, :routing_key => "abc").bind(x1, :routing_key => "def")

ch2 = conn.create_channel
x2  = ch2.topic("bunny.examples.recovery.e2", :durable => false)
q2  = ch2.queue("bunny.examples.recovery.q2", :durable => false)

q2.bind(x2, :routing_key => "abc").bind(x2, :routing_key => "def")

q1.subscribe do |delivery_info, metadata, payload|
  puts "Consumed #{payload} at stage one"
  x2.publish(payload, :routing_key => ["abc", "def", "xyz"].sample)
end

q2.subscribe do |delivery_info, metadata, payload|
  puts "Consumed #{payload} at stage two"
end

loop do
  sleep 2
  rk = ["abc", "def", "ghi", "xyz"].sample
  puts "Publishing with routing key #{rk}"

  begin
    x1.publish(rand.to_s, :routing_key => rk)
  # happens when a message is published before the connection
  # is recovered
  rescue Bunny::ConnectionClosedError => e
  end
end
