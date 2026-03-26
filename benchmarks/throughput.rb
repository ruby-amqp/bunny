#!/usr/bin/env ruby

require "bunny"

MESSAGE_SIZES = [
  ["12 B",    12,       100_000],
  ["1 KiB",   1_024,    100_000],
  ["4 KiB",   4_096,    100_000],
  ["16 KiB",  16_384,   100_000],
]

PREFETCH   = 500
MULTI_ACK  = 100
BATCH_SIZE = 500

puts
puts "-" * 72
puts "Bunny #{Bunny::VERSION} on #{RUBY_DESCRIPTION}"
puts "-" * 72

def run_benchmark(label, size, count, use_batch: false)
  payload = "x" * size

  pub_conn = Bunny.new
  pub_conn.start
  con_conn = Bunny.new
  con_conn.start

  pub_ch = pub_conn.create_channel
  con_ch = con_conn.create_channel
  con_ch.prefetch(PREFETCH)

  q = con_ch.queue("bunny.bench", auto_delete: true)
  q.purge

  received = 0
  done = Queue.new

  q.subscribe(manual_ack: true) do |delivery_info, _properties, _body|
    received += 1
    if (received % MULTI_ACK).zero?
      con_ch.basic_ack(delivery_info.delivery_tag, true)
    end
    done.push(true) if received == count
  end

  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  if use_batch
    payloads = Array.new(BATCH_SIZE, payload)
    (count / BATCH_SIZE).times { pub_ch.basic_publish_batch(payloads, "", q.name, persistent: false) }
    remainder = count % BATCH_SIZE
    if remainder > 0
      pub_ch.basic_publish_batch(Array.new(remainder, payload), "", q.name, persistent: false)
    end
  else
    count.times { pub_ch.basic_publish(payload, "", q.name, persistent: false) }
  end
  done.pop

  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
  rate = (count / elapsed).round(0)
  mb_sec = (count * size / elapsed / 1_048_576.0).round(1)

  pub_conn.close
  con_conn.close

  [label, count, rate, mb_sec]
end

puts
puts "## basic_publish (per-message)"
puts

results = []
MESSAGE_SIZES.each do |label, size, count|
  r = run_benchmark(label, size, count)
  results << r
  printf "%-12s  %6dK msgs  %8d msg/sec  %8.1f MB/sec\n", r[0], r[1] / 1000, r[2], r[3]
end

puts
puts "## basic_publish_batch (#{BATCH_SIZE} msgs/batch)"
puts

batch_results = []
MESSAGE_SIZES.each do |label, size, count|
  r = run_benchmark(label, size, count, use_batch: true)
  batch_results << r
  printf "%-12s  %6dK msgs  %8d msg/sec  %8.1f MB/sec\n", r[0], r[1] / 1000, r[2], r[3]
end

puts
puts "-" * 72
puts "| Workload | basic_publish | batch (#{BATCH_SIZE}) |"
puts "|----------|--------:|-------:|"
results.zip(batch_results).each do |r, br|
  puts "| #{r[1] / 1000}K x #{r[0]} | #{r[2]} msg/sec | #{br[2]} msg/sec |"
end
puts "-" * 72
