#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "bunny"

puts "=> Headers exchange routing"
puts

conn = Bunny.new
conn.start

ch   = conn.create_channel
x    = ch.headers("headers")

q1   = ch.queue("", :exclusive => true).bind(x, :arguments => {"os" => "linux", "cores" => 8, "x-match" => "all"})
q2   = ch.queue("", :exclusive => true).bind(x, :arguments => {"os" => "osx",   "cores" => 4, "x-match" => "any"})

q1.subscribe do |delivery_info, properties, content|
  puts "#{q1.name} received #{content}"
end
q2.subscribe do |delivery_info, properties, content|
  puts "#{q2.name} received #{content}"
end

x.publish("8 cores/Linux", :headers => {"os" => "linux", "cores" => 8})
x.publish("8 cores/OS X",  :headers => {"os" => "osx",   "cores" => 8})
x.publish("4 cores/Linux", :headers => {"os" => "linux", "cores" => 4})

sleep 0.5
conn.close
