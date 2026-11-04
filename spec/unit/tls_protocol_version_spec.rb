# -*- coding: utf-8 -*-
# frozen_string_literal: true
require "spec_helper"

describe Bunny::Session, "TLS protocol version" do
  it "negotiates TLSv1.3 when no tls_protocol is given" do
    server_ctx = OpenSSL::SSL::SSLContext.new
    server_ctx.cert = OpenSSL::X509::Certificate.new(File.read("spec/tls/server_certificate.pem"))
    server_ctx.key = OpenSSL::PKey.read(File.read("spec/tls/server_key.pem"))
    server_ctx.min_version = OpenSSL::SSL::TLS1_3_VERSION
    server = OpenSSL::SSL::SSLServer.new(TCPServer.new("127.0.0.1", 0), server_ctx)
    Thread.new { server.accept rescue nil }

    client_ctx = Bunny.new(tls: true, verify_peer: false, tls_silence_warnings: true).transport.tls_context
    client = OpenSSL::SSL::SSLSocket.new(TCPSocket.new("127.0.0.1", server.to_io.addr[1]), client_ctx)
    client.connect

    expect(client.ssl_version).to eq("TLSv1.3")
  ensure
    client&.close
    server&.close
  end

  it "requires at least TLSv1.2 by default" do
    expect_any_instance_of(OpenSSL::SSL::SSLContext).to receive(:min_version=).with(OpenSSL::SSL::TLS1_2_VERSION).and_call_original

    Bunny.new(tls: true, verify_peer: false, tls_silence_warnings: true)
  end
end
