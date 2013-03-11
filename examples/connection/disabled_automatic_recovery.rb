#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'bunny'

conn = Bunny.new(:heartbeat_interval => 8, :automatically_recover => false)
conn.start

ch = conn.create_channel
x  = ch.topic("bunny.examples.recovery.topic", :durable => false)
q  = ch.queue("bunny.examples.recovery.client_named_queue2", :durable => true)
q.purge

q.bind(x, :routing_key => "abc").bind(x, :routing_key => "def")

loop do
  sleep 1.5
  body = rand.to_s
  puts "Published #{body}"
  x.publish(body, :routing_key => ["abc", "def"].sample)

  sleep 1.5
  _, _, payload = q.pop
  if payload
    puts "Consumed #{payload}"
  else
    puts "Consumed nothing"
  end
end
