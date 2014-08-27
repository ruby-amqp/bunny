#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "bunny"

puts "=> Demonstrating basic.nack"
puts

conn = Bunny.new
conn.start

ch   = conn.create_channel
q    = ch.queue("", :exclusive => true)

20.times do
  q.publish("")
end

20.times do
  delivery_info, _, _ = q.pop(:manual_ack => true)

  if delivery_info.delivery_tag == 20
    # requeue them all at once with basic.nack
    ch.nack(delivery_info.delivery_tag, true, true)
  end
end

puts "Queue #{q.name} still has #{q.message_count} messages in it"

sleep 0.7
puts "Disconnecting..."
conn.close
