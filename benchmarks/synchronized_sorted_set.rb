#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "set"
require "thread"
require "benchmark"

puts
puts "-" * 80
puts "Benchmarking on #{RUBY_DESCRIPTION}"

n  = 2_000_000
s  = SortedSet.new

# warm up the JIT, etc
puts "Doing a warmup run..."
n.times do |i|
  s << 1
  s << i
  s.delete i
  s << i
end

t1  = Benchmark.realtime do
  n.times do |i|
    s << 1
    s << i
    s.delete i
    s << i
  end
end
r1  = (n.to_f/t1.to_f)

s2 = SortedSet.new
m  = Mutex.new
t2  = Benchmark.realtime do
  n.times do |i|
    m.synchronize { s2 << 1 }
    m.synchronize { s2 << i }
    m.synchronize { s2.delete i }
    m.synchronize { s2 << i }
  end
end
r2  = (n.to_f/t2.to_f)

puts "Mixed sorted set ops, rate: #{(r1 / 1000).round(2)} KGHz"
puts "Mixed synchronized sorted set ops, rate: #{(r2 / 1000).round(2)} KGHz"
puts
puts "-" * 80
