# -*- coding: utf-8 -*-
require "spec_helper"

unless ENV["CI"]
  describe "Concurrent consumers sharing a connection" do
    let(:connection) do
      c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed",
                    :automatic_recovery => false, :continuation_timeout => 6000)
      c.start
      c
    end

    after :all do
      connection.close
    end

    def any_not_drained?(qs)
      qs.any? { |q| !q.message_count.zero? }
    end

    context "when publishing thousands of messages over 128K in size" do
      let(:colors) { ["red", "blue", "white"] }

      let(:n) { 32 }
      let(:m) { 1000 }

      it "successfully drain all queues" do
        ch   = connection.create_channel
        body = "абвг"
        x    = ch.topic("bunny.stress.concurrent.consumers.topic", :durable => true)

        chs  = {}
        n.times do |i|
          chs[i] = connection.create_channel
        end
        qs   = []

        n.times do |i|
          t = Thread.new do
            cht = chs[i]

            q = cht.queue("", :exclusive => true)
            q.bind(x.name, :routing_key => colors.sample).subscribe do |delivery_info, meta, payload|
              # no-op
            end
            qs << q
          end
          t.abort_on_exception = true
        end

        sleep 1.0

        5.times do |i|
          m.times do
            x.publish(body, :routing_key => colors.sample)
          end
          puts "Published #{(i + 1) * m} messages..."
        end

        while any_not_drained?(qs)
          sleep 1.0
        end
        puts "Drained all the queues..."

        ch.close
      end
    end
  end
end
