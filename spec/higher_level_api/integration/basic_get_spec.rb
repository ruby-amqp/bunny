require "spec_helper"

describe Bunny::Queue, "#pop" do
  let(:connection) do
    c = Bunny.new
    c.start
    c
  end

  context "with all defaults" do
    it "fetches a messages which is automatically acknowledged" do
      ch = connection.create_channel

      q  = ch.queue("", :exclusive => true)
      x  = ch.default_exchange

      x.publish("xyzzy", :routing_key => q.name)

      sleep(0.5)
      fetched = q.pop
      fetched[:payload].should == "xyzzy"
      q.message_count.should == 0

      ch.close
    end
  end


  context "with an empty queue" do
    it "returns an empty response" do
      ch = connection.create_channel

      q  = ch.queue("", :exclusive => true)
      q.purge

      fetched = q.pop
      fetched[:payload].should == :queue_empty
      q.message_count.should == 0

      ch.close
    end
  end
end
