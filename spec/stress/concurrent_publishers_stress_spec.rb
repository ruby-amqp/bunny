# -*- coding: utf-8 -*-
require "spec_helper"

unless ENV["CI"]
  describe "Concurrent publishers sharing a connection" do
    let(:connection) do
      c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed", :automatically_recover => false, :continuation_timeout => 20.0)
      c.start
      c
    end

    after :all do
      connection.close
    end

    let(:concurrency) { 24 }
    let(:rate)        { 5_000 }

    it "successfully finish publishing" do
      ch = connection.create_channel

      q    = ch.queue("", :exclusive => true)
      body = "сообщение"

      # let the queue name be sent back by RabbitMQ
      sleep 0.25

      chs  = {}
      concurrency.times do |i|
        chs[i] = connection.create_channel
      end

      ts = []

      concurrency.times do |i|
        t = Thread.new do
          cht = chs[i]
          x   = ch.default_exchange

          5.times do |i|
            rate.times do
              x.publish(body, :routing_key => q.name)
            end
            puts "Published #{(i + 1) * rate} messages..."
          end
        end
        t.abort_on_exception = true

        ts << t
      end

      ts.each do |t|
        t.join
      end
    end
  end
end
