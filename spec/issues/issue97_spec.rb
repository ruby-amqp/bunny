require "spec_helper"

describe "Message framing implementation" do
  let(:connection) do
    c = Bunny.new(:user     => "bunny_gem",
                  :password => "bunny_password",
                  :vhost    => "bunny_testbed",
                  :port     => ENV.fetch("RABBITMQ_PORT", 5672))
    c.start
    c
  end

  after :all do
    connection.close if connection.open?
  end


  unless ENV["CI"]
    context "with payload ~ 248K in size including non-ASCII characters" do
      it "successfully frames the message" do
        ch = connection.create_channel

        q  = ch.queue("", :exclusive => true)
        x  = ch.default_exchange

        body = IO.read("spec/issues/issue97_attachment.json")
        x.publish(body, :routing_key => q.name, :persistent => true)

        sleep(1)
        q.message_count.should == 1

        q.purge
        ch.close
      end
    end
  end


  context "with payload of several MBs in size" do
    it "successfully frames the message" do
      ch = connection.create_channel

      q  = ch.queue("", :exclusive => true)
      x  = ch.default_exchange

      as = ("a" * (1024 * 1024 * 4 + 2823777))
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


  context "with payload being 2 bytes less than 128K bytes in size" do
    it "successfully frames the message" do
      ch = connection.create_channel

      q  = ch.queue("", :exclusive => true)
      x  = ch.default_exchange

      as = "a" * (1024 * 128 - 2)
      x.publish(as, :routing_key => q.name, :persistent => true)

      sleep(1)
      q.message_count.should == 1

      q.purge
      ch.close
    end
  end

  context "with payload being 1 byte less than 128K bytes in size" do
    it "successfully frames the message" do
      ch = connection.create_channel

      q  = ch.queue("", :exclusive => true)
      x  = ch.default_exchange

      as = "a" * (1024 * 128 - 1)
      x.publish(as, :routing_key => q.name, :persistent => true)

      sleep(1)
      q.message_count.should == 1

      q.purge
      ch.close
    end
  end

  context "with payload being exactly 128K bytes in size" do
    it "successfully frames the message" do
      ch = connection.create_channel

      q  = ch.queue("", :exclusive => true)
      x  = ch.default_exchange

      as = "a" * (1024 * 128)
      x.publish(as, :routing_key => q.name, :persistent => true)

      sleep(1)
      q.message_count.should == 1

      q.purge
      ch.close
    end
  end


  context "with payload being 1 byte greater than 128K bytes in size" do
    it "successfully frames the message" do
      ch = connection.create_channel

      q  = ch.queue("", :exclusive => true)
      x  = ch.default_exchange

      as = "a" * (1024 * 128 + 1)
      x.publish(as, :routing_key => q.name, :persistent => true)

      sleep(1)
      q.message_count.should == 1

      q.purge
      ch.close
    end
  end

  context "with payload being 2 bytes greater than 128K bytes in size" do
    it "successfully frames the message" do
      ch = connection.create_channel

      q  = ch.queue("", :exclusive => true)
      x  = ch.default_exchange

      as = "a" * (1024 * 128 + 2)
      x.publish(as, :routing_key => q.name, :persistent => true)

      sleep(1)
      q.message_count.should == 1

      q.purge
      ch.close
    end
  end
end
