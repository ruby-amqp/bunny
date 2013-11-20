#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'Bunny'

conn = Bunny.new(:heartbeat_interval => 8)
conn.start

ch0 = conn.create_channel
ch1 = conn.create_channel
ch2 = conn.create_channel
ch3 = conn.create_channel

x   = ch1.topic("hb.examples.recovery.topic", :durable => false)
q1  = ch1.queue("hb.examples.recovery.client_named_queue1", :durable => false)
q2  = ch2.queue("hb.examples.recovery.client_named_queue2", :durable => false)
q3  = ch3.queue("hb.examples.recovery.client_named_queue3", :durable => false)

q1.bind(x, :routing_key => "abc")
q2.bind(x, :routing_key => "def")
q3.bind(x, :routing_key => "xyz")

x0  = ch0.fanout("hb.examples.recovery.fanout0")
x1  = ch1.fanout("hb.examples.recovery.fanout1")
x2  = ch2.fanout("hb.examples.recovery.fanout2")
x3  = ch3.fanout("hb.examples.recovery.fanout3")

q4  = ch1.queue("", :exclusive => true)
q4.bind(x0)

q5  = ch2.queue("", :exclusive => true)
q5.bind(x1)

q6  = ch3.queue("", :exclusive => true)
q6.bind(x2)
q6.bind(x3)


q1.subscribe do |delivery_info, metadata, payload|
  puts "[Q1] Consumed #{payload} on channel #{q1.channel.id}"
  if ch0.open?
    puts "Publishing a reply on channel #{ch0.id} which is open"
    x0.publish(Time.now.to_i.to_s)
  end
end

q2.subscribe do |delivery_info, metadata, payload|
  puts "[Q2] Consumed #{payload} on channel #{q2.channel.id}"

  if ch1.open?
    puts "Publishing a reply on channel #{ch1.id} which is open"
    x1.publish(Time.now.to_i.to_s)
  end
end

q3.subscribe do |delivery_info, metadata, payload|
  puts "[Q3] Consumed #{payload} (consumer 1, channel #{q3.channel.id})"

  if ch2.open?
    puts "Publishing a reply on channel #{ch1.id} which is open"
    x2.publish(Time.now.to_i.to_s)
  end
end

q3.subscribe do |delivery_info, metadata, payload|
  puts "[Q3] Consumed #{payload} (consumer 2, channel #{q3.channel.id})"

  if ch3.open?
    puts "Publishing a reply on channel #{ch3.id} which is open"
    x3.publish(Time.now.to_i.to_s)
  end
end

q4.subscribe do |delivery_info, metadata, payload|
  puts "[Q4] Consumed #{payload} on channel #{q4.channel.id}"
end

q5.subscribe do |delivery_info, metadata, payload|
  puts "[Q5] Consumed #{payload} on channel #{q5.channel.id}"
end

q6.subscribe do |delivery_info, metadata, payload|
  puts "[Q6] Consumed #{payload} on channel #{q6.channel.id}"
end

loop do
  sleep 1
  data = rand.to_s
  rk   = ["abc", "def", "xyz", Time.now.to_i.to_s].sample

  begin
    3.times do
      x.publish(rand.to_s, :routing_key => rk)
      puts "Published #{data}, routing key: #{rk} on channel #{x.channel.id}"
    end
  # happens when a message is published before the connection
  # is recovered
  rescue Exception => e
    puts "Exception: #{e.message}"
    # e.backtrace.each do |line|
    #   puts "\t#{line}"
    # end
  end
end
