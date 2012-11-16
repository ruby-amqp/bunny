require "spec_helper"

describe Bunny::Channel, "#reject" do
  let(:connection) do
    c = Bunny.new
    c.start
    c
  end

  subject do
    connection.create_channel
  end

  context "with requeue = true" do
    it "requeues a message" do
      q = subject.queue("bunny.basic.reject.manual-acks", :exclusive => true)
      x = subject.default_exchange

      x.publish("bunneth", :routing_key => q.name)
      sleep(0.25)
      q.message_count.should == 1
      resp = q.pop(:ack => true)
      dt   = resp[:delivery_details][:delivery_tag]

      subject.reject(dt, true)
      sleep(0.25)
      q.message_count.should == 1

      subject.close
    end
  end

  context "with requeue = false" do
    it "rejects a message" do
      q = subject.queue("bunny.basic.reject.with-requeue-false", :exclusive => true)
      x = subject.default_exchange

      x.publish("bunneth", :routing_key => q.name)
      sleep(0.25)
      q.message_count.should == 1
      resp = q.pop(:ack => true)
      dt   = resp[:delivery_details][:delivery_tag]

      subject.reject(dt, false)
      sleep(0.25)
      q.message_count.should == 0

      subject.close
    end
  end
end
