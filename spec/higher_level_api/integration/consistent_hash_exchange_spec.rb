# -*- coding: utf-8 -*-
require "spec_helper"

unless ENV["CI"]
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

      q1 = ch.queue("", :exclusive => true).bind(x, :routing_key => "15")
      q2 = ch.queue("", :exclusive => true).bind(x, :routing_key => "15")

      sleep 1.0

      5.times do |i|
        m.times do
          x.publish(body, :routing_key => list.sample)
        end
        puts "Published #{(i + 1) * m} messages..."
      end

      sleep 4.0
      q1.message_count.should be > 1000
      q2.message_count.should be > 1000

      ch.close
    end
  end
end
