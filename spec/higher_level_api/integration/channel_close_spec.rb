require "spec_helper"

describe Bunny::Channel do
  let(:connection) do
    c = Bunny.new(username: "bunny_gem", password: "bunny_password", vhost: "bunny_testbed")
    c.start
    c
  end

  after :each do
    connection.close
  end

  context "when closed" do
    it "releases the id" do
      ch = connection.create_channel
      n = ch.number

      expect(ch).to be_open
      ch.close
      expect(ch).to be_closed

      # a new channel with the same id can be created
      connection.create_channel(n)
    end
  end

  context "when double closed" do
    # bunny#528
    it "raises a meaningful exception" do
      ch = connection.create_channel

      expect(ch).to be_open
      ch.close
      expect(ch).to be_closed

      expect { ch.close }.to raise_error(Bunny::ChannelAlreadyClosed)
    end
  end

  context "when double closed after a channel-level protocol exception" do
    # bunny#528
    it "raises a meaningful exception" do
      ch = connection.create_channel

      s  = "bunny-temp-q-#{rand}"

      expect(ch).to be_open
      ch.queue_declare(s, durable: false)

      expect do
        ch.queue_declare(s, durable: true)
      end.to raise_error(Bunny::PreconditionFailed)

      # channel.close is sent and handled concurrently with the test
      sleep 1
      expect(ch).to be_closed

      expect { ch.close }.to raise_error(Bunny::ChannelAlreadyClosed)

      cleanup_ch = connection.create_channel
      cleanup_ch.queue_delete(s)
      cleanup_ch.close
    end
  end
end
