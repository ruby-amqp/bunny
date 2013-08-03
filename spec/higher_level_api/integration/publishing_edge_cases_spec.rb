require "spec_helper"

unless ENV["CI"]
  describe "Message framing implementation" do
    let(:connection) do
      c = Bunny.new(:user     => "bunny_gem",
        :password => "bunny_password",
        :vhost    => "bunny_testbed",
        :port     => ENV.fetch("RABBITMQ_PORT", 5672))
      c.start
      c
    end

    after :each do
      connection.close if connection.open?
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

        x.publish("", :routing_key => q.name, :persistent => false, :mandatory => true)

        sleep(0.5)
        q.message_count.should == 1

        envelope, headers, payload = q.pop

        payload.should == ""

        headers[:content_type].should == "application/octet-stream"
        headers[:delivery_mode].should == 1
        headers[:priority].should == 0

        ch.close
      end
    end
  end
end
