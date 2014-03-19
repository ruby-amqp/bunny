#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'bunny'

HIGH_PRIORITY_Q = "bunny.examples.priority.hilo.high"
LOW_PRIORITY_Q  = "bunny.examples.priority.hilo.low"

conn = Bunny.new(:heartbeat_interval => 8)
conn.start

ch1  = conn.create_channel
ch2  = conn.create_channel
hi_q = ch1.queue(HIGH_PRIORITY_Q, :durable => false)
lo_q = ch2.queue(LOW_PRIORITY_Q,  :durable => false)

ch3  = conn.create_channel
x    = ch3.default_exchange

# create a backlog of low priority messages
30.times do
  x.publish(rand.to_s, :routing_key => LOW_PRIORITY_Q)
end

# and a much smaller one of high priority messages
3.times do
  x.publish(rand.to_s, :routing_key => HIGH_PRIORITY_Q)
end

hi_q.subscribe do |delivery_info, metadata, payload|
  puts "[high] Consumed #{payload}"
end

lo_q.subscribe do |delivery_info, metadata, payload|
  puts "[low] Consumed #{payload}"
end

loop do
  sleep 0.5
  data = rand.to_s
  rk   = [HIGH_PRIORITY_Q, LOW_PRIORITY_Q].sample

  x.publish(data, :routing_key => rk)
  puts "Published #{data}, routing key: #{rk}"
end
