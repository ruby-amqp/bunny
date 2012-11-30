#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"
Bundler.setup

$:.unshift(File.expand_path("../../../lib", __FILE__))

require 'bunny'

b = Bunny.new("amqp://guest:guest@aksjhdkajshdkj.example82737.com")
b.start

