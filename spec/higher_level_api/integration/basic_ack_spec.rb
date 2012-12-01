require "spec_helper"

describe Bunny::Channel, "#ack" do
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

  context "with a valid (known) delivery tag" do
    it "acknowleges a message" do
      q = subject.queue("bunny.basic.ack.manual-acks", :exclusive => true)
      x = subject.default_exchange

      x.publish("bunneth", :routing_key => q.name)
      sleep(0.25)
      q.message_count.should == 1
      delivery_details, properties, content = q.pop(:ack => true)

      subject.ack(delivery_details.delivery_tag, true)
      sleep(0.25)
      q.message_count.should == 0

      subject.close
    end
  end

  context "with an invalid (random) delivery tag" do
    it "causes a channel-level error" do
      pending "We need to design async channel error handling for cases when there is no reply methods (e.g. basic.ack)"

      q = subject.queue("bunny.basic.ack.unknown-delivery-tag", :exclusive => true)
      x = subject.default_exchange

      x.publish("bunneth", :routing_key => q.name)
      sleep(0.25)
      q.message_count.should == 1
      _, _, content = q.pop(:ack => true)

      subject.on_error do |ch, channel_close|
        @channel_close = channel_close
      end
      # subject.ack(82, true)
    end
  end
end
