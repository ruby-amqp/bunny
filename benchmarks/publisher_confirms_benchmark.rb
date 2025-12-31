#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "bunny"
require "benchmark"

TOTAL_MESSAGES = 100_000
BATCH_SIZE = 1024

conn = Bunny.new(username: "bunny_gem", password: "bunny_password", vhost: "bunny_testbed")
conn.start

puts "Benchmarking publisher confirms with #{TOTAL_MESSAGES} messages (batch size: #{BATCH_SIZE})"
puts "=" * 70
puts

# Approach 1: Legacy batch publishing with wait_for_confirms
def legacy_batch_publish(conn, total, batch_size)
  ch = conn.create_channel
  ch.confirm_select
  q = ch.queue("", exclusive: true)
  x = ch.default_exchange

  count = 0
  total.times do
    x.publish("x" * 100, routing_key: q.name)
    count += 1
    if count >= batch_size
      ch.wait_for_confirms
      count = 0
    end
  end
  ch.wait_for_confirms if count > 0

  ch.close
end

# Approach 2: New tracking with outstanding_limit
def tracking_with_limit(conn, total, limit)
  ch = conn.create_channel
  ch.confirm_select(tracking: true, outstanding_limit: limit)
  q = ch.queue("", exclusive: true)
  x = ch.default_exchange

  total.times do
    x.publish("x" * 100, routing_key: q.name)
  end

  ch.wait_for_confirms  # Wait for remaining confirms (fair comparison)
  ch.close
end

# Approach 3: Tracking without limit (each publish blocks, a major anti-pattern)
def tracking_no_limit(conn, total)
  ch = conn.create_channel
  ch.confirm_select(tracking: true)
  q = ch.queue("", exclusive: true)
  x = ch.default_exchange

  total.times do
    x.publish("x" * 100, routing_key: q.name)
  end

  ch.close
end

# Warmup
puts "Warming up..."
legacy_batch_publish(conn, 1000, 100)
tracking_with_limit(conn, 1000, 100)
puts

results = {}

puts "Running benchmarks..."
puts

Benchmark.bm(45) do |bm|
  results[:legacy] = bm.report("Legacy batch (wait_for_confirms):") do
    legacy_batch_publish(conn, TOTAL_MESSAGES, BATCH_SIZE)
  end

  results[:tracking_1024] = bm.report("Tracking (outstanding_limit: 1024):") do
    tracking_with_limit(conn, TOTAL_MESSAGES, 1024)
  end

  results[:tracking_512] = bm.report("Tracking (outstanding_limit: 512):") do
    tracking_with_limit(conn, TOTAL_MESSAGES, 512)
  end

  results[:tracking_256] = bm.report("Tracking (outstanding_limit: 256):") do
    tracking_with_limit(conn, TOTAL_MESSAGES, 256)
  end

  # Only run this for fewer messages, this takes a while
  small_count = [TOTAL_MESSAGES, 5000].min
  results[:tracking_none] = bm.report("Tracking (no limit, #{small_count} msgs):") do
    tracking_no_limit(conn, small_count)
  end
end

puts
puts "Summary:"
puts "-" * 70

legacy_rate = TOTAL_MESSAGES / results[:legacy].real
puts "Legacy batch:              #{legacy_rate.round(0)} msg/sec"

tracking_1024_rate = TOTAL_MESSAGES / results[:tracking_1024].real
puts "Tracking (limit 1024):     #{tracking_1024_rate.round(0)} msg/sec (#{(tracking_1024_rate / legacy_rate * 100).round(1)}% of legacy)"

tracking_512_rate = TOTAL_MESSAGES / results[:tracking_512].real
puts "Tracking (limit 512):      #{tracking_512_rate.round(0)} msg/sec (#{(tracking_512_rate / legacy_rate * 100).round(1)}% of legacy)"

tracking_256_rate = TOTAL_MESSAGES / results[:tracking_256].real
puts "Tracking (limit 256):      #{tracking_256_rate.round(0)} msg/sec (#{(tracking_256_rate / legacy_rate * 100).round(1)}% of legacy)"

small_count = [TOTAL_MESSAGES, 5000].min
tracking_none_rate = small_count / results[:tracking_none].real
puts "Tracking (no limit):       #{tracking_none_rate.round(0)} msg/sec (#{(tracking_none_rate / legacy_rate * 100).round(1)}% of legacy)"

conn.close
