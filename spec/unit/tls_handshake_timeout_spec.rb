# -*- coding: utf-8 -*-
# frozen_string_literal: true
require "spec_helper"

describe Bunny::Session, "#start over TLS" do
  let(:log) { StringIO.new }
  let(:logger) { Logger.new(log) }

  # servers that accept the connection but never speak TLS, like a load balancer in front of a dead node
  def with_silent_tcp_servers(n)
    servers = Array.new(n) { TCPServer.new("127.0.0.1", 0) }
    yield servers.map { |s| s.addr[1] }
  ensure
    servers&.each(&:close)
  end

  def connection_to(ports, opts = {})
    Bunny.new({ hosts: ports.map { |p| "127.0.0.1:#{p}" },
                tls: true,
                verify_peer: false,
                connect_timeout: 0.5,
                automatically_recover: false,
                logger: logger }.merge(opts))
  end

  # the failure mode under test is an unbounded block, so bound the example itself
  def start_connection(connection)
    Bunny::Timeout.timeout(5) { connection.start }
  end

  def timed_out_on?(port)
    log.string.match?(/127\.0\.0\.1:#{port}: TLS handshake timed out/)
  end

  it "gives up on a peer that never completes the handshake" do
    with_silent_tcp_servers(1) do |ports|
      expect { start_connection(connection_to(ports)) }.to raise_error(Bunny::TCPConnectionFailedForAllHosts)

      expect(timed_out_on?(ports.first)).to be true
    end
  end

  it "tries every endpoint" do
    with_silent_tcp_servers(2) do |ports|
      expect { start_connection(connection_to(ports)) }.to raise_error(Bunny::TCPConnectionFailedForAllHosts)

      ports.each { |port| expect(timed_out_on?(port)).to be true }
    end
  end

  it "does not limit the handshake when connect_timeout is 0" do
    with_silent_tcp_servers(1) do |ports|
      transport = connection_to(ports, connect_timeout: 0).transport
      transport.maybe_initialize_socket
      transport.post_initialize_socket
      handshake = Thread.new { transport.connect }

      expect(handshake.join(0.5)).to be_nil

      handshake.kill
    end
  end
end
