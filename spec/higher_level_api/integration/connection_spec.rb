require "spec_helper"

describe Bunny::Session do
  let(:port)     { AMQ::Protocol::DEFAULT_PORT }
  let(:username) { "guest" }

  let(:tls_port) { AMQ::Protocol::TLS_PORT }

  context "initialized via connection URI" do
    after :each do
      subject.close if subject.open?
    end

    context "when schema is not one of [amqp, amqps]" do
      it "raises ArgumentError" do
        expect {
          described_class.new("http://dev.rabbitmq.com")
        }.to raise_error(ArgumentError, /amqp or amqps schema/)
      end
    end


    it "handles amqp:// URIs w/o path part" do
      session = described_class.new("amqp://dev.rabbitmq.com")
      session.start

      session.vhost.should == "/"
      session.host.should == "dev.rabbitmq.com"
      session.port.should == 5672
      session.ssl?.should be_false

      session.close
    end


    context "when URI ends in a slash" do
      it "parses vhost as an empty string" do
        session = described_class.new("amqp://dev.rabbitmq.com/")

        session.hostname.should == "dev.rabbitmq.com"
        session.port.should == 5672
        session.vhost.should == ""
      end
    end

    context "when URI is amqp://dev.rabbitmq.com/a/path/with/slashes" do
      it "raises an ArgumentError" do
        lambda { described_class.new("amqp://dev.rabbitmq.com/a/path/with/slashes") }.should raise_error(ArgumentError)
      end
    end
  end




  context "initialized with all defaults" do
    after :each do
      subject.close if subject.open?
    end

    subject do
      Bunny.new
    end

    it "successfully negotiates the connection" do
      subject.start
      subject.should be_connected

      subject.server_properties.should_not be_nil
      subject.server_capabilities.should_not be_nil

      props = subject.server_properties

      props["product"].should_not be_nil
      props["platform"].should_not be_nil
      props["version"].should_not be_nil
    end
  end

  context "initialized with TCP connection timeout = 5" do
    after :each do
      subject.close if subject.open?
    end

    subject do
      described_class.new(:connection_timeout => 5)
    end

    it "successfully connects" do
      subject.start
      subject.should be_connected

      subject.server_properties.should_not be_nil
      subject.server_capabilities.should_not be_nil

      props = subject.server_properties

      props["product"].should_not be_nil
      props["platform"].should_not be_nil
      props["version"].should_not be_nil
    end
  end

  context "initialized with :host => 127.0.0.1" do
    after :each do
      subject.close if subject.open?
    end

    let(:host)  { "127.0.0.1" }
    subject do
      described_class.new(:host => host)
    end

    it "uses hostname = 127.0.0.1" do
      subject.host.should == host
      subject.hostname.should == host
    end

    it "uses port 5672" do
      subject.port.should == port
    end

    it "uses username = guest" do
      subject.username.should == username
    end
  end

  context "initialized with :hostname => localhost" do
    after :each do
      subject.close if subject.open?
    end

    let(:host)    { "localhost" }
    let(:subject) { described_class.new(:hostname => host) }

    it "uses hostname = localhost" do
      subject.host.should == host
      subject.hostname.should == host
    end

    it "uses port 5672" do
      subject.port.should == port
    end

    it "uses username = guest" do
      subject.username.should == username
      subject.user.should == username
    end
  end

  context "initialized with :ssl => true" do
    after :each do
      subject.close if subject.open?
    end

    let(:subject) { described_class.new(:ssl => true) }

    it "uses TLS port" do
      subject.port.should == tls_port
    end
  end

  context "initialized with :tls => true" do
    after :each do
      subject.close if subject.open?
    end

    let(:subject) { described_class.new(:tls => true) }

    it "uses TLS port" do
      subject.port.should == tls_port
    end
  end


  context "initialized with :host => 127.0.0.1 and non-default credentials" do
    after :each do
      subject.close if subject.open?
    end

    let(:host)     { "127.0.0.1" }
    # see ./bin/ci/before_build.sh
    let(:username) { "bunny_gem" }
    let(:password) { "bunny_password" }
    let(:vhost)    { "bunny_testbed" }

    subject do
      described_class.new(:hostname => host, :username => username, :password => password, :virtual_host => vhost)
    end

    it "successfully connects" do
      5.times { subject.start }
      subject.should be_connected

      subject.server_properties.should_not be_nil
      subject.server_capabilities.should_not be_nil

      props = subject.server_properties

      props["product"].should_not be_nil
      props["platform"].should_not be_nil
      props["version"].should_not be_nil
    end

    it "uses hostname = 127.0.0.1" do
      subject.host.should == host
      subject.hostname.should == host
    end

    it "uses port 5672" do
      subject.port.should == port
    end

    it "uses provided vhost" do
      subject.vhost.should == vhost
      subject.virtual_host.should == vhost
    end

    it "uses provided username" do
      subject.username.should == username
    end

    it "uses provided password" do
      subject.password.should == password
    end
  end


  context "initialized with :host => 127.0.0.1 and non-default credentials (take 2)" do
    after :each do
      subject.close if subject.open?
    end

    let(:host)     { "127.0.0.1" }
    # see ./bin/ci/before_build.sh
    let(:username) { "bunny_gem" }
    let(:password) { "bunny_password" }
    let(:vhost)    { "bunny_testbed" }

    subject do
      described_class.new(:hostname => host, :user => username, :pass => password, :vhost => vhost)
    end

    it "successfully connects" do
      subject.start
      subject.should be_connected

      subject.server_properties.should_not be_nil
      subject.server_capabilities.should_not be_nil

      props = subject.server_properties

      props["product"].should_not be_nil
      props["platform"].should_not be_nil
      props["version"].should_not be_nil
    end

    it "uses hostname = 127.0.0.1" do
      subject.host.should == host
      subject.hostname.should == host
    end

    it "uses port 5672" do
      subject.port.should == port
    end

    it "uses provided username" do
      subject.username.should == username
    end

    it "uses provided password" do
      subject.password.should == password
    end
  end



  context "initialized with :host => 127.0.0.1 and non-default credentials (take 2)" do
    after :all do
      subject.close if subject.open?
    end

    let(:host)     { "127.0.0.1" }
    # see ./bin/ci/before_build.sh
    let(:username) { "bunny_gem" }
    let(:password) { "bunny_password" }
    let(:vhost)    { "bunny_testbed" }
    let(:interval) { 1 }

    subject do
      described_class.new(:hostname => host, :user => username, :pass => password, :vhost => vhost, :heartbeat_interval => interval)
    end

    it "successfully connects" do
      subject.start
      subject.should be_connected

      subject.server_properties.should_not be_nil
      subject.server_capabilities.should_not be_nil

      props = subject.server_properties

      props["product"].should_not be_nil
      props["platform"].should_not be_nil
      props["version"].should_not be_nil
      props["capabilities"].should_not be_nil

      # this is negotiated with RabbitMQ, so we need to
      # establish the connection first
      subject.heartbeat.should == interval
    end
  end



  context "initialized with :host => 127.0.0.1 and INVALID credentials" do
    let(:host)     { "127.0.0.1" }
    # see ./bin/ci/before_build.sh
    let(:username) { "bunny_gem#{Time.now.to_i}" }
    let(:password) { "sdjkfhsdf8ysd8fy8" }
    let(:vhost)    { "___sd89aysd98789" }

    subject do
      described_class.new(:hostname => host, :user => username, :pass => password, :vhost => vhost)
    end

    it "fails to connect" do
      lambda do
        subject.start
      end.should raise_error(Bunny::PossibleAuthenticationFailureError)
    end

    it "uses provided username" do
      subject.username.should == username
    end

    it "uses provided password" do
      subject.password.should == password
    end
  end
end
