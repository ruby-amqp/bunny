require "spec_helper"

describe Bunny::Exchange do
  let(:connection) do
    c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed")
    c.start
    c
  end

  after :each do
    connection.close
  end


  context "of type fanout" do
    context "with a non-predefined name" do
      it "is declared" do
        ch = connection.create_channel

        name = "bunny.tests.exchanges.fanout#{rand}"
        x    = ch.fanout(name)
        x.name.should == name

        x.delete
        ch.close
      end
    end

    context "with a predefined name" do
      it "is NOT declared" do
        ch = connection.create_channel

        name = "amq.fanout"
        x    = ch.fanout(name)
        x.name.should == name

        ch.close
      end
    end

    context "with a name prefixed with 'amq.'" do
      it "raises an exception" do
        ch   = connection.create_channel

        expect {
          ch.fanout("amq.test")
        }.to raise_error(Bunny::AccessRefused)

        ch.should be_closed
        expect {
          ch.fanout("amq.test")
        }.to raise_error(Bunny::ChannelAlreadyClosed)
      end
    end

    context "with the durable property" do
      it "is declared as durable" do
        ch = connection.create_channel

        name = "bunny.tests.exchanges.durable"
        x    = ch.fanout(name, :durable => true)
        x.name.should == name
        x.should be_durable
        x.should_not be_auto_delete

        x.delete
        ch.close
      end
    end


    context "with the auto-delete property" do
      it "is declared as auto-delete" do
        ch = connection.create_channel

        name = "bunny.tests.exchanges.auto-delete"
        x    = ch.fanout(name, :auto_delete => true)
        x.name.should == name
        x.should_not be_durable
        x.should be_auto_delete

        ch.exchange(name, :type => :fanout, :auto_delete => true)

        x.delete
        ch.close
      end
    end


    context "when declared with a different set of attributes" do
      it "raises an exception" do
        ch   = connection.create_channel

        x = ch.fanout("bunny.tests.exchanges.fanout", :auto_delete => true, :durable => false)
        expect {
          # force re-declaration
          ch.exchange_declare("bunny.tests.exchanges.fanout", :direct, :auto_delete => false, :durable => true)
        }.to raise_error(Bunny::PreconditionFailed)

        ch.should be_closed
        expect {
          ch.fanout("bunny.tests.exchanges.fanout", :auto_delete => true, :durable => false)
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
        x.name.should == name

        ch.exchange(name, :type => :direct)

        x.delete
        ch.close
      end
    end

    context "with a predefined name" do
      it "is NOT declared" do
        ch = connection.create_channel

        name = "amq.direct"
        x    = ch.direct(name)
        x.name.should == name

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
        x.name.should == name

        ch.exchange(name, :type => :topic)

        x.delete
        ch.close
      end
    end

    context "with a predefined name" do
      it "is NOT declared" do
        ch = connection.create_channel

        name = "amq.topic"
        x    = ch.topic(name)
        x.name.should == name

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
        x.name.should == name

        x.delete
        ch.close
      end
    end

    context "with a predefined name (amq.match)" do
      it "is NOT declared" do
        ch = connection.create_channel

        name = "amq.match"
        x    = ch.headers(name)
        x.name.should == name

        ch.close
      end
    end

    context "with a predefined name (amq.headers)" do
      it "is NOT declared" do
        ch = connection.create_channel

        name = "amq.headers"
        x    = ch.headers(name)
        x.name.should == name

        ch.close
      end
    end
  end


  context "that is internal" do
    it "can be declared" do
      ch = connection.create_channel
      x  = ch.fanout("bunny.tests.exchanges.internal", :internal => true)
      x.should be_internal
      x.delete

      ch.close
    end
  end

  context "not declared as internal" do
    it "is not internal" do
      ch = connection.create_channel
      x  = ch.fanout("bunny.tests.exchanges.non-internal")
      x.should_not be_internal
      x.delete

      ch.close
    end
  end
end
