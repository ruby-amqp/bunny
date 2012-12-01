#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'bunny'


b = Bunny.new(:heartbeat_interval => 2)
b.start

c = b.create_channel

sleep 10
