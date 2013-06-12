require "spec_helper"

describe Bunny::Queue, "#pop" do
  let(:connection) do
    c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed")
    c.start
    c
  end

  after :all do
    connection.close if connection.open?
  end

  context "with all defaults" do
    it "fetches a messages which is automatically acknowledged" do
      ch = connection.create_channel

      q  = ch.queue("", :exclusive => true)
      x  = ch.default_exchange

      x.publish("xyzzy", :routing_key => q.name)

      sleep(0.5)
      delivery_info, properties, content = q.pop
      content.should == "xyzzy"
      q.message_count.should == 0

      ch.close
    end
  end


  context "with all defaults and a timeout that is never hit" do
    it "fetches a messages which is automatically acknowledged" do
      ch = connection.create_channel

      q  = ch.queue("", :exclusive => true)
      x  = ch.default_exchange

      x.publish("xyzzy", :routing_key => q.name)

      sleep(0.5)
      delivery_info, properties, content = q.pop_waiting(:timeout => 1.0)
      content.should == "xyzzy"
      q.message_count.should == 0

      ch.close
    end
  end


  context "with an empty queue" do
    it "returns an empty response" do
      ch = connection.create_channel

      q  = ch.queue("", :exclusive => true)
      q.purge

      _, _, content = q.pop
      content.should be_nil
      q.message_count.should == 0

      ch.close
    end
  end


  context "with an empty queue and a timeout" do
    it "raises an exception" do
      ch = connection.create_channel

      q  = ch.queue("", :exclusive => true)
      q.purge

      lambda {
        _, _, content = q.pop_waiting(:timeout => 0.5)
      }.should raise_error(Bunny::ClientTimeout)

      ch.close
    end
  end
end
