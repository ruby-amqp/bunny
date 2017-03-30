require "spec_helper"

describe Bunny::Exchange do
  let(:connection) do
    c = Bunny.new(username: "bunny_gem", password: "bunny_password", vhost: "bunny_testbed")
    c.start
    c
  end

  after :each do
    connection.close
  end

  context "of default type" do
    it "is declared with an empty name" do
      ch = connection.create_channel

      x = Bunny::Exchange.default(ch)

      expect(x.name).to eq ''
    end
  end

  context "of type fanout" do
    context "with a non-predefined name" do
      it "is declared" do
        ch = connection.create_channel

        name = "bunny.tests.exchanges.fanout#{rand}"
        x    = ch.fanout(name)
        expect(x.name).to eq name

        x.delete
        ch.close
      end
    end

    context "with a predefined name" do
      it "is NOT declared" do
        ch = connection.create_channel

        name = "amq.fanout"
        x    = ch.fanout(name)
        expect(x.name).to eq name

        ch.close
      end
    end

    context "with a name prefixed with 'amq.'" do
      it "raises an exception" do
        ch   = connection.create_channel

        expect {
          ch.fanout("amq.test")
        }.to raise_error(Bunny::AccessRefused)

        expect(ch).to be_closed
        expect {
          ch.fanout("amq.test")
        }.to raise_error(Bunny::ChannelAlreadyClosed)
      end
    end

    context "with the durable property" do
      it "is declared as durable" do
        ch = connection.create_channel

        name = "bunny.tests.exchanges.durable"
        x    = ch.fanout(name, durable: true)
        expect(x.name).to eq name
        expect(x).to be_durable
        expect(x).not_to be_auto_delete

        x.delete
        ch.close
      end
    end


    context "with the auto-delete property" do
      it "is declared as auto-delete" do
        ch = connection.create_channel

        name = "bunny.tests.exchanges.auto-delete"
        x    = ch.fanout(name, auto_delete: true)
        expect(x.name).to eq name
        expect(x).not_to be_durable
        expect(x).to be_auto_delete

        ch.exchange(name, type: :fanout, auto_delete: true)

        x.delete
        ch.close
      end
    end


    context "when declared with a different set of attributes" do
      it "raises an exception" do
        ch1   = connection.create_channel
        ch2   = connection.create_channel

        x = ch1.fanout("bunny.tests.exchanges.fanout", auto_delete: true, durable: false)
        expect {
          # force re-declaration
          ch2.exchange_declare("bunny.tests.exchanges.fanout", :direct, auto_delete: false, durable: true)
        }.to raise_error(Bunny::PreconditionFailed)

        expect(ch2).to be_closed
        expect {
          ch2.fanout("bunny.tests.exchanges.fanout", auto_delete: true, durable: false)
        }.to raise_error(Bunny::ChannelAlreadyClosed)
      end
    end
  end

  context "of type direct" do
    context "with a non-predefined name" do
      it "is declared" do
        ch = connection.create_channel

        name = "bunny.tests.exchanges.direct"
        x    = ch.direct(name)
        expect(x.name).to eq name

        ch.exchange(name, type: :direct)

        x.delete
        ch.close
      end
    end

    context "with a predefined name" do
      it "is NOT declared" do
        ch = connection.create_channel

        name = "amq.direct"
        x    = ch.direct(name)
        expect(x.name).to eq name

        ch.close
      end
    end
  end

  context "of type topic" do
    context "with a non-predefined name" do
      it "is declared" do
        ch = connection.create_channel

        name = "bunny.tests.exchanges.topic"
        x    = ch.topic(name)
        expect(x.name).to eq name

        ch.exchange(name, type: :topic)

        x.delete
        ch.close
      end
    end

    context "with a predefined name" do
      it "is NOT declared" do
        ch = connection.create_channel

        name = "amq.topic"
        x    = ch.topic(name)
        expect(x.name).to eq name

        ch.close
      end
    end
  end

  context "of type headers" do
    context "with a non-predefined name" do
      it "is declared" do
        ch = connection.create_channel

        name = "bunny.tests.exchanges.headers"
        x    = ch.headers(name)
        expect(x.name).to eq name

        x.delete
        ch.close
      end
    end

    context "with a predefined name (amq.match)" do
      it "is NOT declared" do
        ch = connection.create_channel

        name = "amq.match"
        x    = ch.headers(name)
        expect(x.name).to eq name

        ch.close
      end
    end

    context "with a predefined name (amq.headers)" do
      it "is NOT declared" do
        ch = connection.create_channel

        name = "amq.headers"
        x    = ch.headers(name)
        expect(x.name).to eq name

        ch.close
      end
    end
  end


  context "that is internal" do
    it "can be declared" do
      ch = connection.create_channel
      x  = ch.fanout("bunny.tests.exchanges.internal", internal: true)
      expect(x).to be_internal
      x.delete

      ch.close
    end
  end

  context "not declared as internal" do
    it "is not internal" do
      ch = connection.create_channel
      x  = ch.fanout("bunny.tests.exchanges.non-internal")
      expect(x).not_to be_internal
      x.delete

      ch.close
    end
  end
end
