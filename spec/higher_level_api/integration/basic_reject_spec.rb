require "spec_helper"

describe Bunny::Channel, "#reject" do
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

  context "with requeue = true" do
    it "requeues a message" do
      q = subject.queue("bunny.basic.reject.manual-acks", :exclusive => true)
      x = subject.default_exchange

      x.publish("bunneth", :routing_key => q.name)
      sleep(0.5)
      q.message_count.should == 1
      delivery_info, _, _ = q.pop(:ack => true)

      subject.reject(delivery_info.delivery_tag, true)
      sleep(0.5)
      q.message_count.should == 1

      subject.close
    end
  end

  context "with requeue = false" do
    it "rejects a message" do
      q = subject.queue("bunny.basic.reject.with-requeue-false", :exclusive => true)
      x = subject.default_exchange

      x.publish("bunneth", :routing_key => q.name)
      sleep(0.5)
      q.message_count.should == 1
      delivery_info, _, _ = q.pop(:ack => true)

      subject.reject(delivery_info.delivery_tag, false)
      sleep(0.5)
      q.message_count.should == 0

      subject.close
    end
  end
end
