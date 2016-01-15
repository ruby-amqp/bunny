#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "bunny"

STDOUT.sync = true

conn = Bunny.new
conn.start

ch = conn.create_channel
q  = ch.queue("bunny.examples.hello_world", :auto_delete => true)

q.publish("Hello!", :routing_key => q.name)

# demonstrates a blocking consumer that needs to cancel itself
# in the message handler
q.subscribe(:block => true) do |delivery_info, properties, payload|
  puts "Received #{payload}, cancelling"
  delivery_info.consumer.cancel
end

sleep 1.0
conn.close
