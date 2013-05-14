#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "bunny"
require "ruby-prof"

conn = Bunny.new
conn.start

puts
puts "-" * 80
puts "Benchmarking on #{RUBY_DESCRIPTION}"

n  = 50_000
ch = conn.create_channel
x  = ch.default_exchange
s  = "z" * 4096

# warm up the JIT, etc
puts "Doing a warmup run..."
16000.times { x.publish(s, :routing_key => "anything") }

# give OS, the server and so on some time to catch
# up
sleep 2.0

result = RubyProf.profile do
  n.times { x.publish(s, :routing_key => "anything") }
end

printer = RubyProf::FlatPrinter.new(result)
printer.print(STDOUT, {})
