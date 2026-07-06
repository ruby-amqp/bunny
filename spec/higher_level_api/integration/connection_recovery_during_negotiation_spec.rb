# -*- coding: utf-8 -*-
# frozen_string_literal: true

require "spec_helper"
require "socket"

describe "Connection recovery when the server closes connections during negotiation" do
  # An in-process TCP proxy in front of the RabbitMQ node used by the test
  # suite. In poisoned mode it lets the AMQP handshake proceed and then
  # answers connection.open with connection.close (CONNECTION_FORCED), the
  # way a node that is being drained (put into maintenance mode) before a
  # shutdown does. It can also close established client connections with a
  # server-sent connection.close, like `rabbitmqctl close_all_connections`.
  class NegotiationPoisoningProxy
    # method frame payload prefix: class 10 (connection), method 40 (open)
    CONNECTION_OPEN_SIGNATURE = "\x00\x0A\x00\x28".b

    CONNECTION_FORCED_FRAME = AMQ::Protocol::Connection::Close.encode(
      320, "CONNECTION_FORCED - Node was put into maintenance mode", 0, 0).encode

    attr_reader :port

    def initialize(upstream_host: "127.0.0.1", upstream_port: Integer(ENV.fetch("RABBITMQ_PORT", 5672)))
      @upstream_host = upstream_host
      @upstream_port = upstream_port

      @server = TCPServer.new("127.0.0.1", 0)
      @port   = @server.addr[1]

      @lock              = Mutex.new
      @poisoning         = false
      @poisoned_attempts = 0
      @clients           = []
      @threads           = []
    end

    def poison!
      @lock.synchronize { @poisoning = true }
    end

    def heal!
      @lock.synchronize { @poisoning = false }
    end

    def poisoning?
      @lock.synchronize { @poisoning }
    end

    # @return [Integer] how many connection attempts were rejected during negotiation
    def poisoned_attempts
      @lock.synchronize { @poisoned_attempts }
    end

    # Closes all established client connections with a server-sent
    # connection.close, like a node that is being put into maintenance mode.
    def force_close_established!
      @lock.synchronize { @clients.dup }.each do |client|
        begin
          client.write(CONNECTION_FORCED_FRAME)
        rescue IOError, SystemCallError
          # the client is already gone
        end
      end
    end

    def start
      @acceptor = Thread.new do
        loop do
          begin
            client = @server.accept
          rescue IOError, SystemCallError
            break
          end
          @lock.synchronize { @clients << client }
          @threads << Thread.new(client) { |c| pump(c) }
        end
      end
      self
    end

    def stop
      @server.close rescue nil
      @acceptor.kill if @acceptor
      @threads.each(&:kill)
      @lock.synchronize { @clients.dup }.each { |c| c.close rescue nil }
    end

    private

    def pump(client)
      upstream = TCPSocket.new(@upstream_host, @upstream_port)

      upstream_to_client = Thread.new do
        begin
          loop { client.write(upstream.readpartial(65536)) }
        rescue EOFError, IOError, SystemCallError
        ensure
          client.close rescue nil
          upstream.close rescue nil
        end
      end

      begin
        loop do
          data = client.readpartial(65536)
          if poisoning? && data.include?(CONNECTION_OPEN_SIGNATURE)
            @lock.synchronize { @poisoned_attempts += 1 }
            client.write(CONNECTION_FORCED_FRAME)
            sleep 0.2
            break
          end
          upstream.write(data)
        end
      rescue EOFError, IOError, SystemCallError
      ensure
        upstream.close rescue nil
        client.close rescue nil
        upstream_to_client.join
      end
    ensure
      @lock.synchronize { @clients.delete(client) }
    end
  end

  # Records exceptions Bunny raises into the session thread instead of
  # letting them terminate it, so that the test can assert on them.
  class RecordingSessionErrorHandler
    def initialize
      @lock       = Mutex.new
      @exceptions = []
    end

    def raise(e)
      @lock.synchronize { @exceptions << e }
    end

    def exceptions
      @lock.synchronize { @exceptions.dup }
    end
  end

  let(:logger) { Logger.new($stderr).tap { |l| l.level = ENV.fetch("BUNNY_LOG_LEVEL", Logger::WARN) } }

  def poll_until(&probe)
    Bunny::TestKit.poll_until(30, &probe)
  end

  it "keeps retrying and recovers once the node stops rejecting connections, without raising into the session thread" do
    proxy = NegotiationPoisoningProxy.new.start
    error_handler = RecordingSessionErrorHandler.new

    c = Bunny.new(host: "127.0.0.1",
                  port: proxy.port,
                  network_recovery_interval: 0.2,
                  recover_from_connection_close: true,
                  session_error_handler: error_handler,
                  logger: logger)
    c.start

    begin
      ch = c.create_channel
      q  = ch.queue("bunny.recovery.negotiation", exclusive: true)

      deliveries = Queue.new
      q.subscribe { |_di, _mp, payload| deliveries.push(payload) }

      q.publish("before")
      poll_until { deliveries.length == 1 }

      # The node begins to drain: established connections are force-closed
      # and reconnection attempts are rejected during negotiation.
      proxy.poison!
      proxy.force_close_established!

      # Recovery must survive several rejected attempts...
      poll_until { proxy.poisoned_attempts >= 3 }

      # ...and complete as soon as the node is accepting clients again.
      proxy.heal!
      poll_until { c.open? && ch.open? }

      q.publish("after")
      poll_until { deliveries.length == 2 }
      expect(deliveries.pop).to eq "before"
      expect(deliveries.pop).to eq "after"

      # connection.close during negotiation is handled by the recovery
      # retry logic and is not raised into the session thread
      expect(error_handler.exceptions).to be_empty
    ensure
      c.close(false) rescue nil
      proxy.stop
    end
  end

  it "times out negotiation with a peer that accepts TCP connections but never responds, even with read timeouts disabled" do
    # A "black hole": accepts TCP connections and never writes anything back,
    # like a suspended listener of a node in maintenance mode or an endpoint
    # of a Kubernetes pod whose node was abruptly terminated.
    black_hole = TCPServer.new("127.0.0.1", 0)
    port = black_hole.addr[1]

    c = Bunny.new(host: "127.0.0.1",
                  port: port,
                  read_timeout: 0,
                  connection_timeout: 2,
                  logger: logger)

    started_at = Bunny::Timestamp.monotonic
    expect do
      # the outer timeout turns a regression (an indefinitely blocked
      # handshake) into a fast, clean failure via the elapsed time check below
      Timeout.timeout(15) { c.start }
    end.to raise_error(::Timeout::Error)
    expect(Bunny::Timestamp.monotonic - started_at).to be < 10
  ensure
    black_hole.close rescue nil
  end
end
