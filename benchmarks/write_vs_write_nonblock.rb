#!/usr/bin/env ruby

require "benchmark"

# This tests demonstrates throughput difference of
# IO#write and IO#write_nonblock. Note that the two
# may not be equivalent depending on your

r, w = IO.pipe

# buffer size
b    = 65536

read_loop = Thread.new do
  loop do
    begin
      r.read_nonblock(b)
    rescue Errno::EWOULDBLOCK, Errno::EAGAIN => e
      IO.select([r])
      retry
    end
  end
end

n = 10_000
# 7 KB
s = "a" * (7 * 1024)
Benchmark.bm do |meter|
  meter.report("write:") do
    n.times { w.write(s.dup) }
  end
  meter.report("write + flush:") do
    n.times { w.write(s.dup); w.flush }
  end
  meter.report("write_nonblock:") do
    n.times do
      s2 = s.dup
      begin
        while !s2.empty?
          written = w.write_nonblock(s2)
          s2.slice!(0, written)
        end
      rescue Errno::EWOULDBLOCK, Errno::EAGAIN
        IO.select([], [w])
        retry
      end
    end
  end
end
