require "spec_helper"

if RUBY_VERSION <= "1.9"
  describe "Publishing a message to the default exchange" do
    let(:connection) do
      c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed")
      c.start
      c
    end

    after :each do
      connection.close if connection.open?
    end


    context "with all default delivery and message properties" do
      it "routes messages to a queue with the same name as the routing key" do
        expect(connection).to be_threaded
        ch = connection.create_channel

        q  = ch.queue("", :exclusive => true)
        x  = ch.default_exchange

        x.publish("xyzzy", :routing_key => q.name).
          publish("xyzzy", :routing_key => q.name).
          publish("xyzzy", :routing_key => q.name).
          publish("xyzzy", :routing_key => q.name)

        sleep(1)
        expect(q.message_count).to eq 4

        ch.close
      end
    end


    context "with all default delivery and message properties" do
      it "routes the messages and preserves all the metadata" do
        expect(connection).to be_threaded
        ch = connection.create_channel

        q  = ch.queue("", :exclusive => true)
        x  = ch.default_exchange

        x.publish("xyzzy", :routing_key => q.name, :persistent => true)

        sleep(1)
        expect(q.message_count).to eq 1

        envelope, headers, payload = q.pop

        expect(payload).to eq "xyzzy"

        expect(headers[:content_type]).to eq "application/octet-stream"
        expect(headers[:delivery_mode]).to eq 2
        expect(headers[:priority]).to eq 0

        ch.close
      end
    end


    context "with all default delivery and message properties on a single-threaded connection" do
      let(:connection) do
        c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed", :threaded => false)
        c.start
        c
      end

      it "routes messages to a queue with the same name as the routing key" do
        expect(connection).not_to be_threaded
        ch = connection.create_channel

        q  = ch.queue("", :exclusive => true)
        x  = ch.default_exchange

        x.publish("xyzzy", :routing_key => q.name).
          publish("xyzzy", :routing_key => q.name).
          publish("xyzzy", :routing_key => q.name).
          publish("xyzzy", :routing_key => q.name)

        sleep(1)
        expect(q.message_count).to eq 4

        ch.close
      end
    end
  end
end


describe "Published message" do
  let(:connection) do
    c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed")
    c.start
    c
  end

  after :each do
    connection.close if connection.open?
  end

  context "with all default delivery and a 254 character long routing key" do
    it "routes the messages" do
      ch = connection.create_channel

      q  = ch.queue("", :exclusive => true)
      x  = ch.fanout("amq.fanout")
      q.bind(x)

      rk = "a" * 254
      x.publish("xyzzy", :routing_key => rk, :persistent => true)

      sleep(1)
      expect(q.message_count).to eq 1

      _, _, payload = q.pop

      expect(payload).to eq "xyzzy"

      ch.close
    end
  end

  context "with all default delivery and a 255 character long routing key" do
    it "routes the messages" do
      ch = connection.create_channel

      q  = ch.queue("", :exclusive => true)
      x  = ch.fanout("amq.fanout")
      q.bind(x)

      rk = "a" * 255
      x.publish("xyzzy", :routing_key => rk, :persistent => true)

      sleep(1)
      expect(q.message_count).to eq 1

      _, _, payload = q.pop

      expect(payload).to eq "xyzzy"

      ch.close
    end
  end

  context "with all default delivery and a 256 character long routing key" do
    it "fails with a connection exception" do
      ch = connection.create_channel

      q  = ch.queue("", :exclusive => true)
      x  = ch.fanout("amq.fanout")
      q.bind(x)

      rk = "a" * 256
      expect do
        x.publish("xyzzy", :routing_key => rk, :persistent => true)
      end.to raise_error(ArgumentError)

      ch.close
    end
  end
end
