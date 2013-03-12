# -*- coding: utf-8 -*-
require "spec_helper"

describe "Concurrent publishers sharing a connection" do
  let(:connection) do
    c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed", :automatically_recover => false)
    c.start
    c
  end

  after :all do
    connection.close
  end

  let(:n) { 10 }
  let(:m) { 1000 }

  it "successfully finish publishing" do
    ch = connection.create_channel

    q    = ch.queue("", :exclusive => true)
    body = "сообщение" * 128

    # let the queue name be sent back by RabbitMQ
    sleep 0.25

    ts = []

    n.times do
      t = Thread.new do
        cht = connection.create_channel
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
