# -*- coding: utf-8 -*-
require "spec_helper"

unless ENV["CI"]
  describe "Concurrent publishers sharing a connection" do
    let(:connection) do
      c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed", :automatically_recover => false)
      c.start
      c
    end

    after :all do
      connection.close
    end

    let(:n) { 32 }
    let(:m) { 1000 }

    it "successfully finish publishing" do
      ch = connection.create_channel

      q    = ch.queue("", :exclusive => true)
      body = "сообщение"

      # let the queue name be sent back by RabbitMQ
      sleep 0.25

      chs  = {}
      n.times do |i|
        chs[i] = connection.create_channel
      end

      ts = []

      n.times do |i|
        t = Thread.new do
          cht = chs[i]
          x   = ch.default_exchange

          5.times do |i|
            m.times do
              x.publish(body, :routing_key => q.name)
            end
            puts "Published #{(i + 1) * m} messages..."
          end
        end
        t.abort_on_exception = true

        ts << t
      end

      ts.each do |t|
        t.join
      end

      sleep 4.0
      q.message_count.should == 5 * n * m
    end
  end
end
