#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "bunny"

puts "=> Direct exchange routing"
puts

conn = Bunny.new
conn.start

ch   = conn.create_channel
x    = ch.direct("examples.imaging")

q1 = ch.queue("", :auto_delete => true).bind(x, :routing_key => "resize")
q1.subscribe do |delivery_info, properties, payload|
  puts "[consumer] #{q1.name} received a 'resize' message"
end
q2 = ch.queue("", :auto_delete => true).bind(x, :routing_key => "watermark")
q2.subscribe do |delivery_info, properties, payload|
  puts "[consumer] #{q2.name} received a 'watermark' message"
end

# just an example
data = rand.to_s
x.publish(data, :routing_key => "resize")
x.publish(data, :routing_key => "watermark")

sleep 0.5
x.delete
q1.delete
q2.delete

puts "Disconnecting..."
conn.close
