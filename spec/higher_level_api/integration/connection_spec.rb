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

      expect(session.vhost).to eq "/"
      expect(session.host).to eq "127.0.0.1"
      expect(session.port).to eq 5672
      expect(session.ssl?).to eq false

      session.close
    end

    context "when URI ends in a slash" do
      it "parses vhost as an empty string" do
        session = described_class.new("amqp://127.0.0.1/")

        expect(session.hostname).to eq "127.0.0.1"
        expect(session.port).to eq 5672
        expect(session.vhost).to eq ""
      end
    end

    context "when URI is amqp://dev.rabbitmq.com/a/path/with/slashes" do
      it "raises an ArgumentError" do
        expect { described_class.new("amqp://dev.rabbitmq.com/a/path/with/slashes") }.to raise_error(ArgumentError)
      end
    end
  end

  context "initialized with all defaults" do
    it "provides a way to fine tune socket options" do
      conn = Bunny.new
      conn.start
      expect(conn.transport.socket).to respond_to(:setsockopt)

      conn.close
    end

    it "successfully negotiates the connection" do
      conn = Bunny.new
      conn.start
      expect(conn).to be_connected

      expect(conn.server_properties).not_to be_nil
      expect(conn.server_capabilities).not_to be_nil

      props = conn.server_properties

      expect(props["product"]).not_to be_nil
      expect(props["platform"]).not_to be_nil
      expect(props["version"]).not_to be_nil

      conn.close
    end
  end

  unless ENV["CI"]
    context "initialized with TCP connection timeout = 5" do
      it "successfully connects" do
        conn = described_class.new(connection_timeout: 5)
        conn.start
        expect(conn).to be_connected

        expect(conn.server_properties).not_to be_nil
        expect(conn.server_capabilities).not_to be_nil

        props = conn.server_properties

        expect(props["product"]).not_to be_nil
        expect(props["platform"]).not_to be_nil
        expect(props["version"]).not_to be_nil

        conn.close
      end
    end

    context "initialized with hostname: 127.0.0.1" do
      after :each do
        subject.close if subject.open?
      end

      let(:host)  { "127.0.0.1" }
      subject do
        described_class.new(hostname: host)
      end

      it "uses hostname = 127.0.0.1" do
        expect(subject.host).to eq host
        expect(subject.hostname).to eq host
      end

      it "uses port 5672" do
        expect(subject.port).to eq port
      end

      it "uses username = guest" do
        expect(subject.username).to eq username
      end
    end

    context "initialized with hostname: localhost" do
      after :each do
        subject.close if subject.open?
      end

      let(:host)    { "localhost" }
      let(:subject) { described_class.new(hostname: host) }

      it "uses hostname = localhost" do
        expect(subject.host).to eq host
        expect(subject.hostname).to eq host
      end

      it "uses port 5672" do
        expect(subject.port).to eq port
      end

      it "uses username = guest" do
        expect(subject.username).to eq username
        expect(subject.user).to eq username
      end
    end

    context "initialized with a list of hosts" do
      after :each do
        subject.close if subject.open?
      end

      let(:host)    { "192.168.1.10" }
      let(:hosts)   { [host] }
      let(:subject) { described_class.new(hosts: hosts) }

      it "uses hostname = 192.168.1.10" do
        expect(subject.host).to eq host
        expect(subject.hostname).to eq host
      end

      it "uses port 5672" do
        expect(subject.port).to eq port
      end

      it "uses username = guest" do
        expect(subject.username).to eq username
        expect(subject.user).to eq username
      end
    end

    context "initialized with a list of addresses" do
      after :each do
        subject.close if subject.open?
      end

      let(:host)      { "192.168.1.10" }
      let(:port)      { 5673 }
      let(:address)   { "#{host}:#{port}" }
      let(:addresses) { [address] }
      let(:subject)   { described_class.new(addresses: addresses) }

      it "uses hostname = 192.168.1.10" do
        expect(subject.host).to eq host
        expect(subject.hostname).to eq host
      end

      it "uses port 5673" do
        expect(subject.port).to eq port
      end

      it "uses username = guest" do
        expect(subject.username).to eq username
        expect(subject.user).to eq username
      end
    end

    context "initialized with addresses: [...] with quoted IPv6 hostnames" do
      after :each do
        subject.close if subject.open?
      end

      let(:host)      { "[2001:db8:85a3:8d3:1319:8a2e:370:7348]" }
      let(:port)      { 5673 }
      let(:address)   { "#{host}:#{port}" }
      let(:addresses) { [address] }
      let(:subject)   { described_class.new(addresses: addresses) }

      it "uses correct hostname" do
        expect(subject.host).to eq host
        expect(subject.hostname).to eq host
      end

      it "uses port 5673" do
        expect(subject.port).to eq port
      end

      it "uses username = guest" do
        expect(subject.username).to eq username
        expect(subject.user).to eq username
      end
    end

    context "initialized with addresses: [...] with quoted IPv6 hostnames without ports" do
      after :each do
        subject.close if subject.open?
      end

      let(:host)      { "[2001:db8:85a3:8d3:1319:8a2e:370:7348]" }
      let(:address)   { host }
      let(:addresses) { [address] }
      let(:subject)   { described_class.new(addresses: addresses) }

      it "uses correct hostname" do
        expect(subject.host).to eq host
        expect(subject.hostname).to eq host
      end

      it "uses port 5672" do
        expect(subject.port).to eq 5672
      end

      it "uses username = guest" do
        expect(subject.username).to eq username
        expect(subject.user).to eq username
      end
    end

    context "initialized with addresses: [...] with an quoted IPv6 hostnames" do
      after :each do
        subject.close if subject.open?
      end

      let(:host)      { "2001:db8:85a3:8d3:1319:8a2e:370:7348" }
      let(:port)      { 5673 }
      let(:address)   { "#{host}:#{port}" }
      let(:addresses) { [address] }
      let(:subject)   { described_class.new(addresses: addresses) }

      it "fails to correctly parse the host (and emits a warning)" do
        expect(subject.host).to eq "2001"
        expect(subject.hostname).to eq "2001"
      end

      it "fails to correctly parse the port (and emits a warning)" do
        expect(subject.port).to eq 0
      end

      it "uses username = guest" do
        expect(subject.username).to eq username
        expect(subject.user).to eq username
      end
    end

    context "initialized with conflicting hosts and addresses" do
      let(:host)      { "192.168.1.10" }
      let(:port)      { 5673 }
      let(:address)   { "#{host}:#{port}" }
      let(:io)        { StringIO.new }
      let(:logger)    { ::Logger.new(io) }

      it "raises an argument error when there is are hosts and an address" do
        expect { described_class.new(addresses: [address], hosts: [host]) }.to raise_error(ArgumentError)
      end

      it "logs a warning when there is a single host and an array" do
        described_class.new(addresses: [address], host: host, logger: logger)
        expect(io.string).to match(/both a host and an array of hosts/)
      end

      it "converts hosts in addresses to addresses" do
        strategy = Proc.new { |addresses| addresses }
        session = described_class.new(addresses: [address,host ], hosts_shuffle_strategy: strategy)
        strategy = Proc.new { |addresses| addresses }

        expect(session.to_s).to include 'addresses=[192.168.1.10:5673,192.168.1.10:5672]'
      end
    end

    context "initialized with channel_max: 4096" do
      after :each do
        subject.close if subject.open?
      end

      let(:channel_max) { 1024 }
      let(:subject)     { described_class.new(channel_max: channel_max) }

      # this assumes RabbitMQ has no lower value configured. In 3.2
      # it is 0 (no limit) by default and 1024 is still a fairly low value
      # for future releases. MK.
      it "negotiates channel max to be 1024" do
        subject.start
        expect(subject.channel_max).to eq channel_max

        subject.close
      end
    end

    context "initialized with ssl: true" do
      let(:subject) do
        described_class.new(username: "bunny_gem",
          password: "bunny_password",
          vhost: "bunny_testbed",
          ssl:                 true,
          ssl_cert:            "spec/tls/client_cert.pem",
          ssl_key:             "spec/tls/client_key.pem",
          ssl_ca_certificates: ["./spec/tls/cacert.pem"])
      end

      it "uses TLS port" do
        expect(subject.port).to eq tls_port
      end
    end

    context "initialized with tls: true" do
      let(:subject) do
        described_class.new(username: "bunny_gem",
          password: "bunny_password",
          vhost: "bunny_testbed",
          tls: true,
          tls_cert: "spec/tls/client_certificate.pem",
          tls_key: "spec/tls/client_key.pem",
          tls_ca_certificates: ["./spec/tls/ca_certificate.pem"])
      end

      it "uses TLS port" do
        expect(subject.port).to eq tls_port
      end
    end
  end

  context "initialized with hostname: 127.0.0.1 and non-default credentials" do
    after :each do
      subject.close if subject.open?
    end

    let(:host)     { "127.0.0.1" }
    # see ./bin/ci/before_build
    let(:username) { "bunny_gem" }
    let(:password) { "bunny_password" }
    let(:vhost)    { "bunny_testbed" }

    subject do
      described_class.new(hostname: host, username: username, password: password, virtual_host: vhost)
    end

    it "successfully connects" do
      5.times { subject.start }
      expect(subject).to be_connected

      expect(subject.server_properties).not_to be_nil
      expect(subject.server_capabilities).not_to be_nil

      props = subject.server_properties

      expect(props["product"]).not_to be_nil
      expect(props["platform"]).not_to be_nil
      expect(props["version"]).not_to be_nil
    end

    it "uses hostname = 127.0.0.1" do
      expect(subject.host).to eq host
      expect(subject.hostname).to eq host
    end

    it "uses port 5672" do
      expect(subject.port).to eq port
    end

    it "uses provided vhost" do
      expect(subject.vhost).to eq vhost
      expect(subject.virtual_host).to eq vhost
    end

    it "uses provided username" do
      expect(subject.username).to eq username
    end

    it "uses provided password" do
      expect(subject.password).to eq password
    end
  end

  context "initialized with hostname: 127.0.0.1 and non-default credentials (take 2)" do
    after :each do
      subject.close if subject.open?
    end

    let(:host)     { "127.0.0.1" }
    # see ./bin/ci/before_build
    let(:username) { "bunny_gem" }
    let(:password) { "bunny_password" }
    let(:vhost)    { "bunny_testbed" }

    subject do
      described_class.new(hostname: host, username: username, password: password, vhost: vhost)
    end

    it "successfully connects" do
      subject.start
      expect(subject).to be_connected

      expect(subject.server_properties).not_to be_nil
      expect(subject.server_capabilities).not_to be_nil

      props = subject.server_properties

      expect(props["product"]).not_to be_nil
      expect(props["platform"]).not_to be_nil
      expect(props["version"]).not_to be_nil
    end

    it "uses hostname = 127.0.0.1" do
      expect(subject.host).to eq host
      expect(subject.hostname).to eq host
    end

    it "uses port 5672" do
      expect(subject.port).to eq port
    end

    it "uses provided username" do
      expect(subject.username).to eq username
    end

    it "uses provided password" do
      expect(subject.password).to eq password
    end
  end

  context "initialized with hostname: 127.0.0.1 and non-default credentials (take 2)" do
    after :each do
      subject.close if subject.open?
    end

    let(:host)     { "127.0.0.1" }
    # see ./bin/ci/before_build
    let(:username) { "bunny_gem" }
    let(:password) { "bunny_password" }
    let(:vhost)    { "bunny_testbed" }
    let(:interval) { 1 }

    subject do
      described_class.new(hostname: host, username: username, password: password, vhost: vhost, heartbeat_interval: interval)
    end

    it "successfully connects" do
      subject.start
      expect(subject).to be_connected

      expect(subject.server_properties).not_to be_nil
      expect(subject.server_capabilities).not_to be_nil

      props = subject.server_properties

      expect(props["product"]).not_to be_nil
      expect(props["platform"]).not_to be_nil
      expect(props["version"]).not_to be_nil
      expect(props["capabilities"]).not_to be_nil

      # this is negotiated with RabbitMQ, so we need to
      # establish the connection first
      expect(subject.heartbeat).to eq interval
    end
  end

  context "initialized with hostname: 127.0.0.1 and INVALID credentials" do
    let(:host)     { "127.0.0.1" }
    # see ./bin/ci/before_build
    let(:username) { "bunny_gem#{Time.now.to_i}" }
    let(:password) { "sdjkfhsdf8ysd8fy8" }
    let(:vhost)    { "___sd89aysd98789" }

    subject do
      described_class.new(hostname: host, username: username, password: password, vhost: vhost)
    end

    it "fails to connect" do
      expect do
        subject.start
      end.to raise_error(Bunny::PossibleAuthenticationFailureError)
    end

    it "uses provided username" do
      expect(subject.username).to eq username
    end

    it "uses provided password" do
      expect(subject.password).to eq password
    end
  end

  context "initialized with unreachable host or port" do
    it "fails to connect" do
      expect do
        c = described_class.new(port: 38000)
        c.start
      end.to raise_error(Bunny::TCPConnectionFailed)
    end

    it "is not connected" do
      begin
        c = described_class.new(port: 38000)
        c.start
      rescue Bunny::TCPConnectionFailed => e
        true
      end

      expect(subject.status).to eq :not_connected
    end

    it "is not open" do
      begin
        c = described_class.new(port: 38000)
        c.start
      rescue Bunny::TCPConnectionFailed => e
        true
      end

      expect(subject).not_to be_open
    end
  end

  context "initialized with a custom logger object" do
    let(:io)      { StringIO.new }
    let(:logger)  { ::Logger.new(io) }

    it "uses provided logger" do
      conn = described_class.new(logger: logger)
      conn.start

      expect(io.string.length).to be > 100

      conn.close
    end

    it "doesn't reassign the logger's progname attribute" do
      expect(logger).not_to receive(:progname=)
      described_class.new(logger: logger)
    end
  end
end
