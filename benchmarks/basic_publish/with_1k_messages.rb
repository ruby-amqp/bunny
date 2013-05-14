#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "bunny"
require "benchmark"

conn = Bunny.new
conn.start

puts
puts "-" * 80
puts "Benchmarking on #{RUBY_DESCRIPTION}"

n  = 50_000
ch = conn.create_channel
x  = ch.default_exchange
s  = "z" * 1024

# warm up the JIT, etc
puts "Doing a warmup run..."
16000.times { x.publish(s, :routing_key => "anything") }

# give OS, the server and so on some time to catch
# up
sleep 2.0

t  = Benchmark.realtime do
  n.times { x.publish(s, :routing_key => "anything") }
end
r  = (n.to_f/t.to_f)

puts "Publishing rate with #{s.bytesize} bytes/msg: #{(r / 1000).round(2)} KGHz"
puts
puts "-" * 80
