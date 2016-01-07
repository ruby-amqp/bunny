#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "bunny"

STDOUT.sync = true

puts "=> Demonstrating alternate exchanges"
puts

conn = Bunny.new
conn.start

ch   = conn.create_channel
x1   = ch.fanout("bunny.examples.ae.exchange1", :auto_delete => true, :durable => false)
x2   = ch.fanout("bunny.examples.ae.exchange2", :auto_delete => true, :durable => false, :arguments => {
                   "alternate-exchange" => x1.name
                 })
q    = ch.queue("", :exclusive => true)
q.bind(x1)

x2.publish("")

sleep 0.2
puts "Queue #{q.name} now has #{q.message_count} message in it"

sleep 0.7
puts "Disconnecting..."
conn.close
