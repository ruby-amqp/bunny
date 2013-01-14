#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'bunny'

begin
  conn = Bunny.new("amqp://guest:guest@aksjhdkajshdkj.example82737.com")
  conn.start
rescue Bunny::TCPConnectionFailed => e
  puts "Connection to #{conn.hostname} failed"
end
