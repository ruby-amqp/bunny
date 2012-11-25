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
      resp = q.pop(:ack => true)
      dt   = resp[:delivery_details][:delivery_tag]

      subject.nack(dt, false, false)
      sleep(0.5)
      q.message_count.should == 0

      subject.close
    end
  end

  context "with multiple = true" do
    it "rejects multiple messages"
  end
end
