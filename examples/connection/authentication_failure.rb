#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'bunny'

begin
  conn = Bunny.new("amqp://guest8we78w7e8:guest2378278@127.0.0.1")
  conn.start
rescue Bunny::PossibleAuthenticationFailureError => e
  puts "Could not authenticate as #{conn.username}"
end
