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
q  = ch.queue("", :durable => false)

q.bind(x, :routing_key => "abc").bind(x, :routing_key => "def")

q.subscribe do |delivery_info, metadata, payload|
  puts "Consumed #{payload}"
end

loop do
  sleep 2
  data = rand.to_s
  rk   = ["abc", "def"].sample

  begin
    x.publish(rand.to_s, :routing_key => rk)
  # happens when a message is published before the connection
  # is recovered
  rescue Bunny::ConnectionClosedError => e
  end
end
