#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "bunny"

conn = Bunny.new
conn.start

ch  = conn.create_channel
x   = ch.fanout("nba.scores")

ch.queue("joe",   :auto_delete => true).bind(x).subscribe do |delivery_info, properties, payload|
  puts "#{payload} => joe"
end

ch.queue("aaron", :auto_delete => true).bind(x).subscribe do |delivery_info, properties, payload|
  puts "#{payload} => aaron"
end

ch.queue("bob",   :auto_delete => true).bind(x).subscribe do |delivery_info, properties, payload|
  puts "#{payload} => bob"
end

x.publish("BOS 101, NYK 89").publish("ORL 85, ALT 88")

conn.close
