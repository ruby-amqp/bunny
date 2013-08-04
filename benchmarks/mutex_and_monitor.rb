#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "set"
require "thread"
require "benchmark"
require "monitor"

puts
puts "-" * 80
puts "Benchmarking on #{RUBY_DESCRIPTION}"

n  = 2_000_000
mx = Mutex.new
mt = Monitor.new

# warm up the JIT, etc
puts "Doing a warmup run..."
n.times do |i|
  mx.synchronize { 1 }
  mt.synchronize { 1 }
end

t1  = Benchmark.realtime do
  n.times do |i|
    mx.synchronize { 1 }
  end
end
r1  = (n.to_f/t1.to_f)

t2  = Benchmark.realtime do
  n.times do |i|
    mt.synchronize { 1 }
  end
end
r2  = (n.to_f/t2.to_f)

puts "Mutex#synchronize, rate: #{(r1 / 1000).round(2)} KGHz"
puts "Monitor#synchronize, rate: #{(r2 / 1000).round(2)} KGHz"
puts
puts "-" * 80
