require "spec_helper"

describe "Publishing a message to the default exchange" do
  let(:connection) do
    c = Bunny.new
    c.start
    c
  end

  it "routes messages to a queue with the same name as the routing key" do
    ch = connection.create_channel

    q  = ch.queue("", :exclusive => true)
    x  = ch.default_exchange

    x.publish("xyzzy", :routing_key => q.name).
      publish("xyzzy", :routing_key => q.name).
      publish("xyzzy", :routing_key => q.name).
      publish("xyzzy", :routing_key => q.name)

    sleep(1)
    q.message_count.should == 4

    ch.close
  end
end
