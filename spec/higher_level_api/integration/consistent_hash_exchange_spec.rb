# -*- coding: utf-8 -*-
require "spec_helper"

describe "x-consistent-hash exchange" do
  let(:connection) do
    c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed",
      :automatically_recover => true)
    c.start
    c
  end

  let(:http_client) { RabbitMQ::HTTP::Client.new("http://127.0.0.1:15672") }

  after :each do
    connection.close
  end

  let(:list) { Range.new(0, 6).to_a.map(&:to_s) }

  let(:m) { 1500 }

  let(:exchange_plugin_available) do
    http_client.overview.exchange_types.map(&:name).include?("x-consistent-hash")
  end

  it "distributes messages between queues bound with the same routing key" do
    if exchange_plugin_available
      ch   = connection.create_channel
      body = "сообщение"
      # requires the consistent hash exchange plugin,
      # enable it with
      #
      # $ [sudo] rabbitmq-plugins enable rabbitmq_consistent_hash_exchange
      x    = ch.exchange("bunny.stress.concurrent.consumers", :type => "x-consistent-hash", :durable => true)

      qs = []

      q1 = ch.queue("", :exclusive => true).bind(x, :routing_key => "5")
      q2 = ch.queue("", :exclusive => true).bind(x, :routing_key => "5")

      sleep 1.0

      5.times do |i|
        m.times do
          x.publish(body, :routing_key => list.sample)
        end
        puts "Published #{(i + 1) * m} tiny messages..."
      end

      sleep 2.0
      expect(q1.message_count).to be > 100
      expect(q2.message_count).to be > 100

      ch.close
    else
      skip "x-consistent-hash exchange type isn't available"
    end # if
  end # it
end
