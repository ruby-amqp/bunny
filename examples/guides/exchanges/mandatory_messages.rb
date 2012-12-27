#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "bunny"

puts "=> Publishing messages as mandatory"
puts

conn = Bunny.new
conn.start

ch   = conn.create_channel
x    = ch.default_exchange

x.on_return do |return_info, properties, content|
  puts "Got a returned message: #{content}"
end

q = ch.queue("", :exclusive => true)
q.subscribe do |delivery_info, properties, content|
  puts "Consumed a message: #{content}"
end

x.publish("This will NOT be returned", :mandatory => true, :routing_key => q.name)
x.publish("This will be returned", :mandatory => true, :routing_key => "akjhdfkjsh#{rand}")

sleep 0.5
puts "Disconnecting..."
conn.close
