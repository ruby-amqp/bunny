# -*- coding: utf-8 -*-
require "spec_helper"

require "socket"

CERTIFICATE_DIR = ENV.fetch("BUNNY_CERTIFICATE_DIR", "./spec/tls")
puts "Will use certificates from #{CERTIFICATE_DIR}"

shared_examples_for "successful TLS connection" do
  it "succeeds", skip: ENV["CI"] do
    expect(subject).to be_tls
    ch = subject.create_channel
    ch.confirm_select

    q  = ch.queue("", exclusive: true)
    x  = ch.default_exchange

    x.publish("xyzzy", routing_key: q.name).
      publish("xyzzy", routing_key: q.name).
      publish("xyzzy", routing_key: q.name).
      publish("xyzzy", routing_key: q.name)

    x.wait_for_confirms
    expect(q.message_count).to eq 4

    i = 0
    q.subscribe do |delivery_info, _, payload|
      i += 1
    end
    sleep 1.0
    expect(i).to eq 4
    expect(q.message_count).to eq 0

    ch.close
  end
end

def local_hostname
  ENV.fetch("BUNNY_RABBITMQ_HOSTNAME", "localhost")
end

context "initialized with tls: true", skip: ENV["CI"] do
  let(:subject) do
    Bunny.new(
      hostname:  local_hostname(),
      user:     "bunny_gem",
      password: "bunny_password",
      vhost:    "bunny_testbed",
      tls: true,
      verify_peer: verify_peer,
      tls_cert: "#{CERTIFICATE_DIR}/client_certificate.pem",
      tls_key: "#{CERTIFICATE_DIR}/client_key.pem",
      tls_ca_certificates: ["#{CERTIFICATE_DIR}/ca_certificate.pem"])
  end

  context "peer verification is off" do
    let(:verify_peer) { false }

    it "uses TLS port" do
      expect(subject.port).to eq AMQ::Protocol::TLS_PORT
    end

    it "sends the SNI details" do
      # https://github.com/ruby-amqp/bunny/issues/440
      subject.start
      expect(subject.transport.socket.hostname).to_not be_empty
    end

    after :each do
      subject.close
    end
  end

  context "peer verification is on" do
    let(:verify_peer) { true }

    it "uses TLS port" do
      expect(subject.port).to eq AMQ::Protocol::TLS_PORT
    end
  end
end

describe "TLS connection to RabbitMQ with client certificates", skip: ENV["CI"] do
  let(:subject) do
    c = Bunny.new(
      hostname: local_hostname(),
      username: "bunny_gem",
      password: "bunny_password",
      vhost: "bunny_testbed",
      tls: true,
      tls_protocol: :TLSv1_2,
      tls_cert: "#{CERTIFICATE_DIR}/client_certificate.pem",
      tls_key: "#{CERTIFICATE_DIR}/client_key.pem",
      tls_ca_certificates: ["#{CERTIFICATE_DIR}/ca_certificate.pem"],
      verify_peer: false)
    c.start
    c
  end

  after :each do
    subject.close
  end

  include_examples "successful TLS connection"
end


describe "TLS connection to RabbitMQ without client certificates", skip: ENV["CI"] do
  let(:subject) do
    c = Bunny.new(
      hostname: local_hostname(),
      username: "bunny_gem",
      password: "bunny_password",
      vhost: "bunny_testbed",
      tls: true,
      tls_protocol: :TLSv1_2,
      tls_ca_certificates: ["#{CERTIFICATE_DIR}/ca_certificate.pem"],
      verify_peer: false)
    c.start
    c
  end

  after :each do
    subject.close
  end

  include_examples "successful TLS connection"
end


describe "TLS connection to RabbitMQ with a connection string", skip: ENV["CI"] do
  let(:subject) do
    c = Bunny.new("amqps://bunny_gem:bunny_password@#{local_hostname()}/bunny_testbed",
      tls_protocol: :TLSv1_2,
      tls_cert: "#{CERTIFICATE_DIR}/client_certificate.pem",
      tls_key: "#{CERTIFICATE_DIR}/client_key.pem",
      tls_ca_certificates: ["#{CERTIFICATE_DIR}/ca_certificate.pem"],
      verify_peer: false)
    c.start
    c
  end

  after :each do
    subject.close
  end

  include_examples "successful TLS connection"

  context "when URI contains query parameters" do
    subject(:session) do
      Bunny.new("amqps://bunny_gem:bunny_password@#{local_hostname()}/bunny_testbed?heartbeat=10&connection_timeout=100&channel_max=1000&verify=false&cacertfile=#{CERTIFICATE_DIR}/ca_certificate.pem&certfile=#{CERTIFICATE_DIR}/client_certificate.pem&keyfile=#{CERTIFICATE_DIR}/client_key.pem")
    end

    it "parses extra connection parameters" do
      session.start

      expect(session.uses_tls?).to eq(true)
      expect(session.transport.verify_peer).to eq(false)
      expect(session.transport.tls_ca_certificates).to eq(["#{CERTIFICATE_DIR}/ca_certificate.pem"])
      expect(session.transport.tls_certificate_path).to eq("#{CERTIFICATE_DIR}/client_certificate.pem")
      expect(session.transport.tls_key_path).to eq("#{CERTIFICATE_DIR}/client_key.pem")
    end
  end
end


describe "TLS connection to RabbitMQ with a connection string and w/o client certificate and key", skip: ENV["CI"] do
  let(:subject) do
    c = Bunny.new("amqps://bunny_gem:bunny_password@#{local_hostname()}/bunny_testbed",
      tls_ca_certificates: ["#{CERTIFICATE_DIR}/ca_certificate.pem"],
      tls_protocol: :TLSv1_2,
      verify_peer: verify_peer)
    c.start
    c
  end

  after :each do
    subject.close
  end

  context "peer verification is off" do
    let(:verify_peer) { false }

    include_examples "successful TLS connection"

    it "sends the SNI details" do
      # https://github.com/ruby-amqp/bunny/issues/440
      expect(subject.transport.socket.hostname).to_not be_empty
    end
  end

  context "peer verification is on" do
    let(:verify_peer) { true }

    include_examples "successful TLS connection"

    it "sends the SNI details" do
      # https://github.com/ruby-amqp/bunny/issues/440
      expect(subject.transport.socket.hostname).to_not be_empty
    end
  end
end

describe "TLS connection to RabbitMQ w/o client certificate", skip: ENV["CI"] do
  let(:subject) do
    c = Bunny.new("amqps://bunny_gem:bunny_password@#{local_hostname()}/bunny_testbed",
      tls_ca_certificates: ["#{CERTIFICATE_DIR}/ca_certificate.pem"],
      tls_protocol: :TLSv1_2,
      verify_peer: false,
      tls_silence_warnings: should_silence_warnings)
    c.start
    c
  end

  after :each do
    subject.close
  end

  context "TLS-related warnings are enabled" do
    let(:should_silence_warnings) { false }

    include_examples "successful TLS connection"
  end

  context "TLS-related warnings are silenced" do
    let(:should_silence_warnings) { true }

    include_examples "successful TLS connection"
  end
end


describe "TLS connection to RabbitMQ with client certificates provided inline", skip: ENV["CI"] do
  let(:subject) do
    c = Bunny.new(
      hostname: local_hostname(),
      username: "bunny_gem",
      password: "bunny_password",
      vhost: "bunny_testbed",
      tls: true,
      tls_cert: File.read("#{CERTIFICATE_DIR}/client_certificate.pem"),
      tls_key: File.read("#{CERTIFICATE_DIR}/client_key.pem"),
      tls_ca_certificates: ["#{CERTIFICATE_DIR}/ca_certificate.pem"],
      tls_protocol: :TLSv1_2,
      verify_peer: false)
    c.start
    c
  end

  after :each do
    subject.close
  end

  include_examples "successful TLS connection"
end
