# -*- coding: utf-8 -*-
require "spec_helper"

describe "x-consistent-hash exchanges" do
  let(:connection) do
    c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed")
    c.start
    c
  end

  after :all do
    connection.close
  end

  let(:list) { Range.new(0, 30).to_a.map(&:to_s) }

  let(:n) { 20 }
  let(:m) { 10_000 }

  it "can be used" do
    ch   = connection.create_channel
    body = "сообщение"
    # requires the consistent hash exchange plugin,
    # enable it with
    #
    # $ [sudo] rabbitmq-plugins enable rabbitmq_consistent_hash_exchange
    x    = ch.exchange("bunny.stress.concurrent.consumers", :type => "x-consistent-hash", :durable => true)

    qs = []

    n.times do
      t = Thread.new do
        cht = connection.create_channel

        q = cht.queue("", :exclusive => true).bind(x, :routing_key => list.sample)
        qs << q
      end
      t.abort_on_exception = true
    end

    sleep 1.0

    5.times do |i|
      m.times do
        x.publish(body, :routing_key => list.sample)
      end
      puts "Published #{(i + 1) * m} messages..."
    end

    sleep 1.0
    qs.any? { |q| q.message_count >= 50 }.should be_true

    ch.close
  end
end
