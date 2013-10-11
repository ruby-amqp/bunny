# -*- coding: utf-8 -*-
require "spec_helper"

unless ENV["CI"]
  shared_examples_for "successful TLS connection" do
    it "succeeds" do
      connection.should be_tls
      ch = connection.create_channel

      q  = ch.queue("", :exclusive => true)
      x  = ch.default_exchange

      x.publish("xyzzy", :routing_key => q.name).
        publish("xyzzy", :routing_key => q.name).
        publish("xyzzy", :routing_key => q.name).
        publish("xyzzy", :routing_key => q.name)

      sleep 0.5
      q.message_count.should == 4

      i = 0
      q.subscribe do |delivery_info, _, payload|
        i += 1
      end
      sleep 1.0
      i.should == 4
      q.message_count.should == 0

      ch.close
    end
  end


  describe "TLS connection to RabbitMQ with client certificates" do
    let(:connection) do
      c = Bunny.new(:user     => "bunny_gem",
        :password => "bunny_password",
        :vhost    => "bunny_testbed",
        :tls                   => true,
        :tls_cert              => "spec/tls/client_cert.pem",
        :tls_key               => "spec/tls/client_key.pem",
        :tls_ca_certificates   => ["./spec/tls/cacert.pem"])
      c.start
      c
    end

    after :each do
      connection.close
    end

    include_examples "successful TLS connection"
  end


  describe "TLS connection to RabbitMQ without client certificates" do
    let(:connection) do
      c = Bunny.new(:user     => "bunny_gem",
        :password => "bunny_password",
        :vhost    => "bunny_testbed",
        :tls                   => true,
        :tls_ca_certificates   => ["./spec/tls/cacert.pem"])
      c.start
      c
    end

    after :each do
      connection.close
    end

    include_examples "successful TLS connection"
  end


  describe "TLS connection to RabbitMQ with a connection string" do
    let(:connection) do
      c = Bunny.new("amqps://bunny_gem:bunny_password@127.0.0.1/bunny_testbed",
        :tls_cert              => "spec/tls/client_cert.pem",
        :tls_key               => "spec/tls/client_key.pem",
        :tls_ca_certificates   => ["./spec/tls/cacert.pem"])
      c.start
      c
    end

    after :each do
      connection.close
    end

    include_examples "successful TLS connection"
  end


  describe "TLS connection to RabbitMQ with a connection string and w/o client certificate and key" do
    let(:connection) do
      c = Bunny.new("amqps://bunny_gem:bunny_password@127.0.0.1/bunny_testbed",
        :tls_ca_certificates   => ["./spec/tls/cacert.pem"])
      c.start
      c
    end

    after :each do
      connection.close
    end

    include_examples "successful TLS connection"
  end


  describe "TLS connection to RabbitMQ with client certificates provided inline" do
    let(:connection) do
      c = Bunny.new(:user     => "bunny_gem",
        :password => "bunny_password",
        :vhost    => "bunny_testbed",
        :tls                   => true,
        :tls_cert              => File.read("./spec/tls/client_cert.pem"),
        :tls_key               => File.read("./spec/tls/client_key.pem"),
        :tls_ca_certificates   => ["./spec/tls/cacert.pem"])
      c.start
      c
    end

    after :each do
      connection.close
    end

    include_examples "successful TLS connection"
  end
end
