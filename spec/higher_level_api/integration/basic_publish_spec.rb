require "spec_helper"

describe "Publishing a message to the default exchange" do
  let(:connection) do
    c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed")
    c.start
    c
  end

  after :all do
    connection.close if connection.open?
  end


  context "with all default delivery and message properties" do
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


  context "with all default delivery and message properties" do
    it "routes the messages and preserves all the metadata" do
      ch = connection.create_channel

      q  = ch.queue("", :exclusive => true)
      x  = ch.default_exchange

      x.publish("xyzzy", :routing_key => q.name, :persistent => true)

      sleep(1)
      q.message_count.should == 1

      envelope, headers, payload = q.pop

      payload.should == "xyzzy"

      headers[:content_type].should == "application/octet-stream"
      headers[:delivery_mode].should == 2
      headers[:priority].should == 0

      ch.close
    end
  end


  context "with payload exceeding 128 Kb (max frame size)" do
    it "successfully frames the message" do
      ch = connection.create_channel

      q  = ch.queue("", :exclusive => true)
      x  = ch.default_exchange

      as = ("a" * (1024 * 1024 * 4 + 28237777))
      x.publish(as, :routing_key => q.name, :persistent => true)

      sleep(1)
      q.message_count.should == 1

      _, _, payload      = q.pop
      payload.bytesize.should == as.bytesize

      ch.close
    end
  end



  context "with empty message body" do
    it "successfully publishes the message" do
      ch = connection.create_channel

      q  = ch.queue("", :exclusive => true)
      x  = ch.default_exchange

      x.publish("", :routing_key => q.name, :persistent => true)

      sleep(1)
      q.message_count.should == 1

      envelope, headers, payload = q.pop

      payload.should == ""

      headers[:content_type].should == "application/octet-stream"
      headers[:delivery_mode].should == 2
      headers[:priority].should == 0

      ch.close
    end
  end
end
