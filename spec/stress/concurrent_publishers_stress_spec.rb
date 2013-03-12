# -*- coding: utf-8 -*-
require "spec_helper"

describe "Concurrent publishers sharing a connection" do
  let(:connection) do
    c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed")
    c.start
    c
  end

  after :all do
    connection.close
  end

  let(:n) { 3 }
  let(:m) { 50_000 }

  xit "successfully finish publishing" do
    ch = connection.create_channel

    q    = ch.queue("", :exclusive => true)
    body = "сообщение кириллицей" * 1024

    # let the queue name be sent back by RabbitMQ
    sleep 0.25

    ts = []

    n.times do
      t = Thread.new do
        cht = connection.create_channel
        x   = ch.default_exchange

        x.publish(body, :routing_key => q.name)
      end
      t.abort_on_exception = true

      ts << t
    end

    sleep 1.0
    ts.each do |t|
      t.join
    end

    puts q.message_count
  end
end
