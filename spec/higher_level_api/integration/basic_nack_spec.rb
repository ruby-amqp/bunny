require "spec_helper"

describe Bunny::Channel, "#nack" do
  let(:connection) do
    c = Bunny.new(username: "bunny_gem", password: "bunny_password", vhost: "bunny_testbed")
    c.start
    c
  end

  after :each do
    connection.close if connection.open?
  end

  subject do
    connection.create_channel
  end

  context "with requeue = false" do
    it "rejects a message" do
      q = subject.queue("bunny.basic.nack.with-requeue-false", exclusive: true)
      x = subject.default_exchange

      x.publish("bunneth", routing_key: q.name)
      sleep(0.5)
      expect(q.message_count).to eq 1
      delivery_info, _, content = q.pop(manual_ack: true)

      subject.nack(delivery_info.delivery_tag, false, false)
      sleep(0.5)
      subject.close

      ch = connection.create_channel
      q = ch.queue("bunny.basic.nack.with-requeue-false", exclusive: true)
      expect(q.message_count).to eq 0
      ch.close
    end
  end

  context "with multiple = true" do
    it "rejects multiple messages" do
q = subject.queue("bunny.basic.nack.with-requeue-true-multi-true", exclusive: true)
      x = subject.default_exchange

      3.times do
        x.publish("bunneth", routing_key: q.name)
      end
      sleep(0.5)
      expect(q.message_count).to eq 3
      _, _, _ = q.pop(manual_ack: true)
      _, _, _ = q.pop(manual_ack: true)
      delivery_info, _, content = q.pop(manual_ack: true)

      subject.nack(delivery_info.delivery_tag, true, true)
      sleep(0.5)
      expect(q.message_count).to eq 3

      subject.close
    end
  end


  context "with an invalid (random) delivery tag" do
    it "causes a channel-level error" do
      q = subject.queue("bunny.basic.nack.unknown-delivery-tag", exclusive: true)
      x = subject.default_exchange

      x.publish("bunneth", routing_key: q.name)
      sleep(0.25)
      expect(q.message_count).to eq 1
      _, _, content = q.pop(manual_ack: true)

      subject.on_error do |ch, channel_close|
        @channel_close = channel_close
      end
      subject.nack(82, false, true)

      sleep 0.5

      expect(@channel_close.reply_text).to eq "PRECONDITION_FAILED - unknown delivery tag 82"
    end
  end
end
