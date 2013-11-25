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
          described_class.new("http://127.0.0.1")
        }.to raise_error(ArgumentError, /amqp or amqps schema/)
      end
    end


    it "handles amqp:// URIs w/o path part" do
      session = described_class.new("amqp://127.0.0.1")
      session.start

      session.vhost.should == "/"
      session.host.should == "127.0.0.1"
      session.port.should == 5672
      session.ssl?.should be_false

      session.close
    end


    context "when URI ends in a slash" do
      it "parses vhost as an empty string" do
        session = described_class.new("amqp://127.0.0.1/")

        session.hostname.should == "127.0.0.1"
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
    it "provides a way to fine tune socket options" do
      conn = Bunny.new
      conn.start
      conn.transport.socket.should respond_to(:setsockopt)

      conn.close
    end

    it "successfully negotiates the connection" do
      conn = Bunny.new
      conn.start
      conn.should be_connected

      conn.server_properties.should_not be_nil
      conn.server_capabilities.should_not be_nil

      props = conn.server_properties

      props["product"].should_not be_nil
      props["platform"].should_not be_nil
      props["version"].should_not be_nil

      conn.close
    end
  end

  unless ENV["CI"]
    context "initialized with TCP connection timeout = 5" do
      it "successfully connects" do
        conn = described_class.new(:connection_timeout => 5)
        conn.start
        conn.should be_connected

        conn.server_properties.should_not be_nil
        conn.server_capabilities.should_not be_nil

        props = conn.server_properties

        props["product"].should_not be_nil
        props["platform"].should_not be_nil
        props["version"].should_not be_nil

        conn.close
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

    context "initialized with :channel_max => 4096" do
      after :each do
        subject.close if subject.open?
      end

      let(:channel_max) { 1024 }
      let(:subject)     { described_class.new(:channel_max => channel_max) }

      # this assumes RabbitMQ has no lower value configured. In 3.2
      # it is 0 (no limit) by default and 1024 is still a fairly low value
      # for future releases. MK.
      it "negotiates channel max to be 1024" do
        subject.start
        subject.channel_max.should == channel_max

        subject.close
      end
    end

    context "initialized with :ssl => true" do
      let(:subject) do
        described_class.new(:user     => "bunny_gem",
          :password => "bunny_password",
          :vhost    => "bunny_testbed",
          :ssl                   => true,
          :ssl_cert              => "spec/tls/client_cert.pem",
          :ssl_key               => "spec/tls/client_key.pem",
          :ssl_ca_certificates   => ["./spec/tls/cacert.pem"])
      end

      it "uses TLS port" do
        subject.port.should == tls_port
      end
    end

    context "initialized with :tls => true" do
      let(:subject) do
        described_class.new(:user     => "bunny_gem",
          :password => "bunny_password",
          :vhost    => "bunny_testbed",
          :tls                   => true,
          :tls_cert              => "spec/tls/client_cert.pem",
          :tls_key               => "spec/tls/client_key.pem",
          :tls_ca_certificates   => ["./spec/tls/cacert.pem"])
      end

      it "uses TLS port" do
        subject.port.should == tls_port
      end
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
    after :each do
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


  context "initialized with unreachable host or port" do
    it "fails to connect" do
      lambda do
        c = described_class.new(:port => 38000)
        c.start
      end.should raise_error(Bunny::TCPConnectionFailed)
    end

    it "is not connected" do
      begin
        c = described_class.new(:port => 38000)
        c.start
      rescue Bunny::TCPConnectionFailed => e
        true
      end

      subject.status.should == :not_connected
    end

    it "is not open" do
      begin
        c = described_class.new(:port => 38000)
        c.start
      rescue Bunny::TCPConnectionFailed => e
        true
      end

      subject.should_not be_open
    end
  end


  context "initialized with a custom logger object" do
    let(:io)      { StringIO.new }
    let(:logger)  { ::Logger.new(io) }

    it "uses provided logger" do
      conn = described_class.new(:hostname => "localhost", :logger => logger)
      conn.start

      io.string.length.should > 100

      conn.close
    end
  end
end
