require "spec_helper"

describe Bunny::Channel, "#nack" do
  let(:connection) do
    c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed")
    c.start
    c
  end

  after :all do
    connection.close if connection.open?
  end

  subject do
    connection.create_channel
  end

  context "with requeue = false" do
    it "rejects a message" do
      q = subject.queue("bunny.basic.nack.with-requeue-false", :exclusive => true)
      x = subject.default_exchange

      x.publish("bunneth", :routing_key => q.name)
      sleep(0.5)
      q.message_count.should == 1
      delivery_info, _, content = q.pop(:ack => true)

      subject.nack(delivery_info.delivery_tag, false, false)
      sleep(0.5)
      q.message_count.should == 0

      subject.close
    end
  end

  context "with multiple = true" do
    it "rejects multiple messages"
  end


  context "with an invalid (random) delivery tag" do
    it "causes a channel-level error" do
      q = subject.queue("bunny.basic.nack.unknown-delivery-tag", :exclusive => true)
      x = subject.default_exchange

      x.publish("bunneth", :routing_key => q.name)
      sleep(0.25)
      q.message_count.should == 1
      _, _, content = q.pop(:ack => true)

      subject.on_error do |ch, channel_close|
        @channel_close = channel_close
      end
      subject.nack(82, false, true)

      sleep 0.5

      @channel_close.reply_text.should == "PRECONDITION_FAILED - unknown delivery tag 82"
    end
  end
end
