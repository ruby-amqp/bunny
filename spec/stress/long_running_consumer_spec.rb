# -*- coding: utf-8 -*-
require "spec_helper"

unless ENV["CI"]
  require "bunny/concurrent/condition"
  require "bunny/test_kit"

  describe "Long running [relatively to heartbeat interval] consumer that never publishes" do
    before :all do
      @connection = Bunny.new(username: "bunny_gem",
        password: "bunny_password", vhost: "bunny_testbed",
        automatic_recovery: false, heartbeat_interval: 6)
      @connection.start
    end

    after :all do
      @connection.close
    end

    let(:target) { 256 * 1024 * 1024 }
    let(:queue)  { "bunny.stress.long_running_consumer.#{Time.now.to_i}" }

    let(:rate) { 50 }
    let(:s)    { 4.0 }



    it "does not skip heartbeats" do
      finished = Bunny::Concurrent::Condition.new

      ct = Thread.new do
        t  = 0
        ch = @connection.create_channel(nil, 6)
        begin
          q  = ch.queue(queue, exclusive: true)

          q.bind("amq.fanout").subscribe do |_, _, payload|
            t += payload.bytesize

            if t >= target
              puts "Hit the target, done with the test..."

              finished.notify_all
            else
              puts "Consumed #{(t.to_f / target.to_f).round(3) * 100}% of data"
            end
          end
        rescue Interrupt => e
          ch.maybe_kill_consumer_work_pool!
          ch.close rescue nil
        end
      end
      ct.abort_on_exception = true

      pt = Thread.new do
        t  = 0
        ch = @connection.create_channel
        begin
          x  = ch.fanout("amq.fanout")

          loop do
            break if t >= target

            rate.times do |i|
              msg = Bunny::TestKit.message_in_kb(96, 8192, i)
              x.publish(msg)
              t += msg.bytesize
            end

            sleep (s * rand)
          end
        rescue Interrupt => e
          ch.close rescue nil
        end
      end
      pt.abort_on_exception = true

      finished.wait

      ct.raise Interrupt.new
      pt.raise Interrupt.new
    end
  end
end
