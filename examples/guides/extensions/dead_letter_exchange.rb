#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "bunny"

puts "=> Demonstrating dead letter exchange"
puts

conn = Bunny.new
conn.start

ch   = conn.create_channel
x    = ch.fanout("amq.fanout")
dlx  = ch.fanout("bunny.examples.dlx.exchange")
q    = ch.queue("", :exclusive => true, :arguments => {"x-dead-letter-exchange" => dlx.name}).bind(x)
# dead letter queue
dlq  = ch.queue("", :exclusive => true).bind(dlx)

x.publish("")
sleep 0.2

delivery_info, _, _ = q.pop(:manual_ack => true)
puts "#{dlq.message_count} messages dead lettered so far"
puts "Rejecting a message"
ch.nack(delivery_info.delivery_tag)
sleep 0.2
puts "#{dlq.message_count} messages dead lettered so far"

dlx.delete
puts "Disconnecting..."
conn.close
