# -*- coding: utf-8 -*-
require "spec_helper"

unless ENV["CI"]
  describe "Concurrent publishers sharing a connection" do
    before :all do
      @connection = Bunny.new(username: "bunny_gem", password: "bunny_password",
        vhost: "bunny_testbed", automatically_recover: false)
      @connection.start
    end

    after :all do
      @connection.close
    end

    let(:concurrency) { 24 }
    let(:messages)    { 5_000 }

    it "successfully finish publishing" do
      body = "сообщение"

      chs  = {}
      concurrency.times do |i|
        ch     = @connection.create_channel
        ch.confirm_select
        chs[i] = ch
      end

      ts = []

      concurrency.times do |i|
        t = Thread.new do
          cht = chs[i]
          x   = cht.default_exchange

          messages.times do
            x.publish(body)
          end
          puts "Published #{messages} messages..."
          cht.wait_for_confirms
        end
        t.abort_on_exception = true

        ts << t
      end

      ts.each do |t|
        t.join
      end

      chs.each { |_, ch| ch.close }
    end
  end
end
