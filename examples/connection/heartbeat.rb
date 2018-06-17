#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'bunny'


conn = Bunny.new(:heartbeat_timeout => 2)
conn.start

c = conn.create_channel

sleep 10
