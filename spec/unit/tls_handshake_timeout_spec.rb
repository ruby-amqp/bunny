# -*- coding: utf-8 -*-
# frozen_string_literal: true
require "spec_helper"

describe Bunny::SSLSocket, "#connect_with_timeout" do
  # TCP server that accepts connections but never performs the TLS handshake
  # (like a load balancer in front of an unresponsive node)
  def with_silent_tcp_server
    server = TCPServer.new("127.0.0.1", 0)
    yield server.addr[1]
  ensure
    server.close
  end

  def new_client_socket(port)
    ctx = OpenSSL::SSL::SSLContext.new
    ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE
    socket = Bunny::SSLSocket.new(TCPSocket.new("127.0.0.1", port), ctx)
    socket.sync_close = true
    socket
  end

  it "raises Bunny::ClientTimeout when the peer never completes the handshake" do
    with_silent_tcp_server do |port|
      socket = new_client_socket(port)
      started_at = Bunny::Timestamp.monotonic

      expect { socket.connect_with_timeout(0.5) }.to raise_error(Bunny::ClientTimeout)

      elapsed = Bunny::Timestamp.monotonic - started_at
      expect(elapsed).to be >= 0.4
      expect(elapsed).to be < 5

      socket.close
    end
  end
end

describe Bunny::Session, "#start over TLS" do
  let(:logger) { Logger.new(IO::NULL) }

  def with_silent_tcp_server
    server = TCPServer.new("127.0.0.1", 0)
    yield server.addr[1]
  ensure
    server.close
  end

  it "raises Bunny::ClientTimeout instead of blocking when the peer never completes the handshake" do
    with_silent_tcp_server do |port|
      conn = Bunny.new(host: "127.0.0.1",
                       port: port,
                       tls: true,
                       verify_peer: false,
                       connect_timeout: 0.5,
                       automatically_recover: false,
                       logger: logger)
      started_at = Bunny::Timestamp.monotonic

      expect { conn.start }.to raise_error(Bunny::ClientTimeout)
      expect(Bunny::Timestamp.monotonic - started_at).to be < 5
    end
  end
end
