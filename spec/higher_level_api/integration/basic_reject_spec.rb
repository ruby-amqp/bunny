require "spec_helper"

describe Bunny::Channel, "#reject" do
  let(:connection) do
    c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed")
    c.start
    c
  end

  after :each do
    connection.close if connection.open?
  end

  context "with requeue = true" do
    it "requeues a message" do
      ch = connection.create_channel
      q  = ch.queue("bunny.basic.reject.manual-acks", :exclusive => true)
      x  = ch.default_exchange

      x.publish("bunneth", :routing_key => q.name)
      sleep(0.5)
      q.message_count.should == 1
      delivery_info, _, _ = q.pop(:ack => true)

      ch.reject(delivery_info.delivery_tag, true)
      sleep(0.5)
      q.message_count.should == 1

      ch.close
    end
  end

  context "with requeue = false" do
    it "rejects a message" do
      ch = connection.create_channel
      q  = ch.queue("bunny.basic.reject.with-requeue-false", :exclusive => true)
      x  = ch.default_exchange

      x.publish("bunneth", :routing_key => q.name)
      sleep(0.5)
      q.message_count.should == 1
      delivery_info, _, _ = q.pop(:ack => true)

      ch.reject(delivery_info.delivery_tag, false)
      sleep(0.5)
      q.message_count.should == 0

      ch.close
    end
  end


  context "with an invalid (random) delivery tag" do
    it "causes a channel-level error" do
      ch = connection.create_channel
      q  = ch.queue("bunny.basic.reject.unknown-delivery-tag", :exclusive => true)
      x  = ch.default_exchange

      x.publish("bunneth", :routing_key => q.name)
      sleep(0.25)
      q.message_count.should == 1
      _, _, content = q.pop(:ack => true)

      ch.on_error do |ch, channel_close|
        @channel_close = channel_close
      end
      ch.reject(82, true)

      sleep 0.5

      @channel_close.reply_text.should == "PRECONDITION_FAILED - unknown delivery tag 82"
    end
  end
end
