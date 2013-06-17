#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "bunny"

puts "=> Demonstrating connection.blocked"
puts

conn = Bunny.new
conn.start

ch   = conn.create_channel
x    = ch.fanout("amq.fanout")

# This example requires high memory watermark to be set
# really low to demonstrate blocking.
#
# rabbitmqctl set_vm_memory_high_watermark 0.00000001
#
# should do it.

conn.on_blocked do |connection_blocked|
  puts "Connection is blocked. Reason: #{connection_blocked.reason}"
end

conn.on_unblocked do |connection_unblocked|
  puts "Connection is unblocked."
end

x.publish("z" * 1024 * 1024 * 16)

sleep 120.0
puts "Disconnecting..."
conn.close
