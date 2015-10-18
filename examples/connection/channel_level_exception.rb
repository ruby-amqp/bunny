#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'bunny'

conn = Bunny.new(:heartbeat_interval => 8)
conn.start

begin
  ch2 = conn.create_channel
  q   = "bunny.examples.recovery.q#{rand}"

  ch2.queue_declare(q, :durable => false)
  ch2.queue_declare(q, :durable => true)
rescue Bunny::PreconditionFailed => e
  puts "Channel-level exception! Code: #{e.channel_close.reply_code}, message: #{e.channel_close.reply_text}"
ensure
  conn.create_channel.queue_delete(q)
end

puts "Disconnecting..."
conn.close
