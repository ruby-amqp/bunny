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

n  = 500

# warm up the JIT, etc
puts "Doing a warmup run..."
1000.times { conn.create_channel }

t  = Benchmark.realtime do
  n.times { conn.create_channel }
end
r  = (n.to_f/t.to_f)

puts "channel.open rate: #{(r / 1000).round(2)} KGHz"
puts
puts "-" * 80
