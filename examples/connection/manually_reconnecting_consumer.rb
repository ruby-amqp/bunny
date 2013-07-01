#!/usr/bin/env ruby
require 'bunny'

Bundler.setup

begin
  connection = Bunny.new(:automatically_recover => false)
  connection.start

  ch = connection.channel
  q  = ch.queue("manually_reconnecting_consumer", :exclusive => true)

  q.subscribe(:block => true) do |_, _, payload|
    puts "Consumed #{payload}"
  end
rescue Bunny::NetworkFailure => e
  ch.maybe_kill_consumer_work_pool!

  sleep 10
  puts "Recovering manually..."

  retry
end
