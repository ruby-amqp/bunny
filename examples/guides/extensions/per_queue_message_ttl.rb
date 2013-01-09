#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "bunny"

puts "=> Demonstrating per-queue message TTL"
puts

conn = Bunny.new
conn.start

ch   = conn.create_channel
x    = ch.fanout("amq.fanout")
q    = ch.queue("", :exclusive => true, :arguments => {"x-message-ttl" => 1000}).bind(x)

10.times do |i|
  x.publish("Message #{i}")
end

sleep 0.7
_, _, content1 = q.pop
puts "Fetched #{content1.inspect} after 0.7 second"

sleep 0.8
_, _, content2 = q.pop
msg = if content2
        content2.inspect
      else
        "nothing"
      end
puts "Fetched #{msg} after 1.5 second"

sleep 0.7
puts "Closing..."
conn.close
