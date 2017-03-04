# -*- coding: utf-8 -*-
require "spec_helper"

unless ENV["CI"]
  describe "Concurrent consumers sharing a connection" do
    before :all do
      @connection = Bunny.new(username: "bunny_gem", password: "bunny_password", vhost: "bunny_testbed",
                    automatic_recovery: false, continuation_timeout: 45000)
      @connection.start
    end

    after :all do
      @connection.close
    end

    def any_not_drained?(qs)
      qs.any? { |q| !q.message_count.zero? }
    end

    context "when publishing thousands of messages over 128K in size" do
      let(:colors) { ["red", "blue", "white"] }

      let(:n) { 16 }
      let(:m) { 5000 }

      it "successfully drain all queues" do
        ch0  = @connection.create_channel
        ch0.confirm_select
        body = "абвг"
        x    = ch0.topic("bunny.stress.concurrent.consumers.topic", durable: true)

        chs  = {}
        n.times do |i|
          chs[i] = @connection.create_channel
        end
        qs   = []

        n.times do |i|
          t = Thread.new do
            cht = chs[i]

            q = cht.queue("", exclusive: true)
            q.bind(x.name, routing_key: colors.sample).subscribe do |delivery_info, meta, payload|
              # no-op
            end
            qs << q
          end
          t.abort_on_exception = true
        end

        sleep 1.0

        5.times do |i|
          m.times do
            x.publish(body, routing_key: colors.sample)
          end
          puts "Published #{(i + 1) * m} messages..."
          ch0.wait_for_confirms
        end

        while any_not_drained?(qs)
          sleep 1.0
        end
        puts "Drained all queues, winding down..."

        ch0.close
        chs.each { |_, ch| ch.close }
      end
    end
  end
end
