#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "bunny"

puts "=> Demonstrating sender-selected distribution"
puts

conn = Bunny.new
conn.start

ch   = conn.create_channel
x    = ch.direct("bunny.examples.ssd.exchange")
q1   = ch.queue("", :exclusive => true).bind(x, :routing_key => "one")
q2   = ch.queue("", :exclusive => true).bind(x, :routing_key => "two")
q3   = ch.queue("", :exclusive => true).bind(x, :routing_key => "three")
q4   = ch.queue("", :exclusive => true).bind(x, :routing_key => "four")

10.times do |i|
  x.publish("Message #{i}", :routing_key => "one", :headers => {"CC" => ["two", "three"]})
end

sleep 0.2
puts "Queue #{q1.name} now has #{q1.message_count} messages in it"
puts "Queue #{q2.name} now has #{q2.message_count} messages in it"
puts "Queue #{q3.name} now has #{q3.message_count} messages in it"
puts "Queue #{q4.name} now has #{q4.message_count} messages in it"

sleep 0.7
puts "Closing..."
conn.close
