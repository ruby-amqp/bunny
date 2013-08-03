require "spec_helper"

describe Bunny::Queue, "#pop" do
  let(:connection) do
    c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed",
                  :automatically_recover => false)
    c.start
    c
  end

  after :each do
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
end
