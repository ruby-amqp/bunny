# -*- coding: utf-8 -*-
require "spec_helper"

unless ENV["CI"]
  CERTIFICATE_DIR=ENV.fetch("BUNNY_CERTIFICATE_DIR", "./spec/tls")
  puts "Will use certificates from #{CERTIFICATE_DIR}"

  shared_examples_for "successful TLS connection" do
    it "succeeds" do
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
    ENV.fetch("BUNNY_RABBITMQ_HOSTNAME", "127.0.0.1")
  end

  context "initialized with :tls => true" do
    let(:subject) do
      Bunny.new(:user     => "bunny_gem",
        :password => "bunny_password",
        :vhost    => "bunny_testbed",
        :tls                   => true,
        :verify_peer           => verify_peer,
        :tls_cert              => "#{CERTIFICATE_DIR}/client_certificate.pem",
        :tls_key               => "#{CERTIFICATE_DIR}/client_key.pem",
        :tls_ca_certificates   => ["#{CERTIFICATE_DIR}/ca_certificate.pem"])
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

  describe "TLS connection to RabbitMQ with client certificates" do
    let(:subject) do
      c = Bunny.new(username: "bunny_gem",
        password: "bunny_password",
        vhost: "bunny_testbed",
        tls: true,
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


  describe "TLS connection to RabbitMQ without client certificates" do
    let(:subject) do
      c = Bunny.new(username: "bunny_gem",
        password: "bunny_password",
        vhost: "bunny_testbed",
        tls: true,
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


  describe "TLS connection to RabbitMQ with a connection string" do
    let(:subject) do
      c = Bunny.new("amqps://bunny_gem:bunny_password@#{local_hostname}/bunny_testbed",
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


  describe "TLS connection to RabbitMQ with a connection string and w/o client certificate and key" do
    let(:subject) do
      c = Bunny.new("amqps://bunny_gem:bunny_password@#{local_hostname}/bunny_testbed",
        tls_ca_certificates: ["#{CERTIFICATE_DIR}/ca_certificate.pem"],
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


  describe "TLS connection to RabbitMQ with client certificates provided inline" do
    let(:subject) do
      c = Bunny.new(username: "bunny_gem",
        password: "bunny_password",
        vhost: "bunny_testbed",
        tls: true,
        tls_cert: File.read("#{CERTIFICATE_DIR}/client_certificate.pem"),
        tls_key: File.read("#{CERTIFICATE_DIR}/client_key.pem"),
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

  describe "TLS connection to RabbitMQ with tls_version TLSv1.1 specified" do
    let(:subject) do
      c = Bunny.new(username: "bunny_gem",
        password: "bunny_password",
        vhost: "bunny_testbed",
        tls: true,
        tls_protocol: :TLSv1_1,
        tls_ca_certificates: ["#{CERTIFICATE_DIR}/ca_certificate.pem"],
        verify_peer: false)
      c.start
      c
    end

    after :each do
      subject.close
    end

    include_examples "successful TLS connection"

    it "connects using TLSv1.1" do
      expect(subject.transport.socket.ssl_version).to eq "TLSv1.1"
    end
  end
end
