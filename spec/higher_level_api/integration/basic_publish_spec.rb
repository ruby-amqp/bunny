require "spec_helper"

describe "Published message" do
  let(:connection) do
    c = Bunny.new(username: "bunny_gem", password: "bunny_password", vhost: "bunny_testbed")
    c.start
    c
  end

  after :each do
    connection.close if connection.open?
  end

  context "with all default delivery and a 254 character long routing key" do
    it "routes the messages" do
      ch = connection.create_channel

      q  = ch.queue("", exclusive: true)
      x  = ch.fanout("amq.fanout")
      q.bind(x)

      rk = "a" * 254
      x.publish("xyzzy", routing_key: rk, persistent: true)

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

      q  = ch.queue("", exclusive: true)
      x  = ch.fanout("amq.fanout")
      q.bind(x)

      rk = "a" * 255
      x.publish("xyzzy", routing_key: rk, persistent: true)

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

      q  = ch.queue("", exclusive: true)
      x  = ch.fanout("amq.fanout")
      q.bind(x)

      rk = "a" * 256
      expect do
        x.publish("xyzzy", routing_key: rk, persistent: true)
      end.to raise_error(ArgumentError)

      ch.close
    end
  end
end
