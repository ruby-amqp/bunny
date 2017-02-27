# -*- coding: utf-8 -*-
require "spec_helper"

unless ENV["CI"]
  describe "Message framing implementation" do
    let(:connection) do
      c = Bunny.new(:user     => "bunny_gem",
        password:  "bunny_password",
        :vhost    => "bunny_testbed",
        :port     => ENV.fetch("RABBITMQ_PORT", 5672))
      c.start
      c
    end

    after :each do
      connection.close if connection.open?
    end


    context "with payload 272179 bytes in size" do
      it "successfully frames the message" do
        ch = connection.create_channel

        q  = ch.queue("", exclusive: true)
        x  = ch.default_exchange

        as = ("a" * 272179)
        x.publish(as, routing_key:  q.name, persistent: true)

        sleep(1)
        expect(q.message_count).to eq 1

        _, _, payload      = q.pop
        expect(payload.bytesize).to eq as.bytesize

        ch.close
      end
    end
  end
end
