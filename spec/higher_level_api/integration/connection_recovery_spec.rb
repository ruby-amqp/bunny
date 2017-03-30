require "spec_helper"
require "rabbitmq/http/client"

describe "Connection recovery" do
  let(:http_client) { RabbitMQ::HTTP::Client.new("http://127.0.0.1:15672") }
  let(:logger) { Logger.new($stderr).tap {|logger| logger.level = ENV["BUNNY_LOG_LEVEL"] || Logger::WARN } }
  let(:recovery_interval) { 0.2 }

  it "reconnects after grace period" do
    with_open do |c|
      close_all_connections!
      wait_for_recovery_with { connections.any? }
    end
  end

  it "reconnects after grace period (with multiple hosts)" do
    with_open_multi_host do |c|
      close_all_connections!
      wait_for_recovery_with { connections.any? }
    end
  end

  it "reconnects after grace period (with multiple hosts, including a broken one)" do
    with_open_multi_broken_host do |c|
      close_all_connections!
      wait_for_recovery_with { connections.any? }
    end
  end

  it "recovers channels" do
    with_open do |c|
      ch1 = c.create_channel
      ch2 = c.create_channel
      sleep 1.5
      close_all_connections!
      sleep 0.5
      poll_until { channels.count == 2 }
      expect(ch1).to be_open
      expect(ch2).to be_open
    end
  end

  it "recovers channels (with multiple hosts)" do
    with_open_multi_host do |c|
      ch1 = c.create_channel
      ch2 = c.create_channel
      sleep 1.5
      close_all_connections!
      sleep 0.5
      poll_until { channels.count == 2 }
      expect(ch1).to be_open
      expect(ch2).to be_open
    end
  end

  it "recovers channels (with multiple hosts, including a broken one)" do
    with_open_multi_broken_host do |c|
      ch1 = c.create_channel
      ch2 = c.create_channel
      sleep 1.5
      close_all_connections!
      sleep 0.5
      poll_until { channels.count == 2 }
      expect(ch1).to be_open
      expect(ch2).to be_open
    end
  end

  it "recovers basic.qos prefetch setting" do
    with_open do |c|
      ch = c.create_channel
      ch.prefetch(11)
      expect(ch.prefetch_count).to eq 11
      expect(ch.prefetch_global).to be false
      sleep 1.5
      close_all_connections!
      sleep 0.5
      wait_for_recovery_with { connections.any? }
      expect(ch).to be_open
      expect(ch.prefetch_count).to eq 11
      expect(ch.prefetch_global).to be false
    end
  end

  it "recovers basic.qos prefetch global setting" do
    with_open do |c|
      ch = c.create_channel
      ch.prefetch(42, true)
      expect(ch.prefetch_count).to eq 42
      expect(ch.prefetch_global).to be true
      sleep 1.5
      close_all_connections!
      sleep 0.5
      wait_for_recovery_with { connections.any? }
      expect(ch).to be_open
      expect(ch.prefetch_count).to eq 42
      expect(ch.prefetch_global).to be true
    end
  end

  it "recovers publisher confirms setting" do
    with_open do |c|
      ch = c.create_channel
      ch.confirm_select
      expect(ch).to be_using_publisher_confirms
      sleep 1.5
      close_all_connections!
      sleep 0.5
      wait_for_recovery_with { connections.any? }
      expect(ch).to be_open
      expect(ch).to be_using_publisher_confirms
    end
  end

  it "recovers transactionality setting" do
    with_open do |c|
      ch = c.create_channel
      ch.tx_select
      expect(ch).to be_using_tx
      sleep 1.5
      close_all_connections!
      sleep 0.5
      wait_for_recovery_with { connections.any? }
      expect(ch).to be_open
      expect(ch).to be_using_tx
    end
  end

  it "recovers client-named queues" do
    with_open do |c|
      ch = c.create_channel
      q  = ch.queue("bunny.tests.recovery.client-named#{rand}")
      close_all_connections!
      wait_for_recovery_with { connections.any? }
      expect(ch).to be_open
      ensure_queue_recovery(ch, q)
      q.delete
    end
  end

  # a very simplistic test for queues inspired by #422
  it "recovers client-named queues declared with no_declare: true" do
    with_open do |c|
      ch  = c.create_channel
      ch2 = c.create_channel

      n   = rand
      s   = "bunny.tests.recovery.client-named#{n}"

      q   = ch.queue(s)
      q2  = ch2.queue(s, no_declare: true)

      close_all_connections!
      wait_for_recovery_with { connections.any? }
      expect(ch).to be_open
      ensure_queue_recovery(ch, q)
      q.delete
    end
  end

  # a test for #422
  it "recovers client-named queues declared with passive: true" do
    with_open do |c|
      ch  = c.create_channel
      ch2 = c.create_channel

      n   = rand
      s   = "bunny.tests.recovery.client-named#{n}"

      q   = ch.queue(s)
      q2  = ch2.queue(s, passive: true)

      close_all_connections!
      wait_for_recovery_with { connections.any? }
      expect(ch).to be_open
      ensure_queue_recovery(ch, q)
      ensure_queue_recovery(ch, q2)
      q.delete
    end
  end

  it "recovers server-named queues" do
    with_open do |c|
      ch = c.create_channel
      q  = ch.queue("", exclusive: true)
      close_all_connections!
      wait_for_recovery_with { connections.any? }
      expect(ch).to be_open
      ensure_queue_recovery(ch, q)
    end
  end

  it "recovers queue bindings" do
    with_open do |c|
      ch = c.create_channel
      x  = ch.fanout("amq.fanout")
      q  = ch.queue("", exclusive: true)
      q.bind(x)
      close_all_connections!
      wait_for_recovery_with { connections.any? }
      expect(ch).to be_open
      ensure_queue_binding_recovery(ch, x, q)
    end
  end

  it "recovers exchanges and their bindings" do
    with_open do |c|
      ch          = c.create_channel
      source      = ch.fanout("source.exchange.recovery.example", auto_delete: true)
      destination = ch.fanout("destination.exchange.recovery.example", auto_delete: true)

      destination.bind(source)

      # Exchanges won't get auto-deleted on connection loss unless they have
      # had an exclusive queue bound to them.
      dst_queue   = ch.queue("", exclusive: true)
      dst_queue.bind(destination, routing_key: "")

      src_queue   = ch.queue("", exclusive: true)
      src_queue.bind(source, routing_key: "")

      close_all_connections!

      wait_for_recovery_with { exchange_names_in_vhost("/").include?(source.name) }
      ch.confirm_select

      source.publish("msg", routing_key: "")
      ch.wait_for_confirms
      expect(dst_queue.message_count).to eq 1
      destination.delete
    end
  end

  it "recovers passively declared exchanges and their bindings" do
    with_open do |c|
      ch          = c.create_channel
      ch.confirm_select

      source      = ch.fanout("amq.fanout", passive: true)
      destination = ch.fanout("destination.exchange.recovery.example", auto_delete: true)

      destination.bind(source)

      # Exchanges won't get auto-deleted on connection loss unless they have
      # had an exclusive queue bound to them.
      dst_queue   = ch.queue("", exclusive: true)
      dst_queue.bind(destination, routing_key: "")

      src_queue   = ch.queue("", exclusive: true)
      src_queue.bind(source, routing_key: "")

      close_all_connections!

      wait_for_recovery_with { connections.any? }

      source.publish("msg", routing_key: "")
      ch.wait_for_confirms

      expect(dst_queue.message_count).to eq 1
      destination.delete
    end
  end

  # this is a simplistic test that primarily execises the code path from #412
  it "recovers exchanges that were declared with passive = true" do
    with_open do |c|
      ch          = c.create_channel
      ch2         = c.create_channel
      source      = ch.fanout("source.exchange.recovery.example", auto_delete: true)
      destination = ch.fanout("destination.exchange.recovery.example", auto_delete: true)

      source2      = ch2.fanout("source.exchange.recovery.example", no_declare: true)
      destination2 = ch2.fanout("destination.exchange.recovery.example", no_declare: true)

      destination.bind(source)

      # Exchanges won't get auto-deleted on connection loss unless they have
      # had an exclusive queue bound to them.
      dst_queue   = ch.queue("", exclusive: true)
      dst_queue.bind(destination, routing_key: "")

      src_queue   = ch.queue("", exclusive: true)
      src_queue.bind(source, routing_key: "")

      close_all_connections!

      wait_for_recovery_with { exchange_names_in_vhost("/").include?(source.name) }

      ch2.confirm_select

      source2.publish("msg", routing_key: "")
      ch2.wait_for_confirms
      expect(dst_queue.message_count).to eq 1
    end
  end

  it "recovers allocated channel ids" do
    with_open do |c|
      q = "queue#{Time.now.to_i}"
      10.times { c.create_channel }
      expect(c.queue_exists?(q)).to eq false
      close_all_connections!
      wait_for_recovery_with { channels.any? }
      # make sure the connection isn't closed shortly after
      # due to "second 'channel.open' seen". MK.
      expect(c).to be_open
      sleep 0.1
      expect(c).to be_open
      sleep 0.1
      expect(c).to be_open
    end
  end

  it "recovers consumers" do
    with_open do |c|
      delivered = false

      ch = c.create_channel
      ch.confirm_select
      q  = ch.queue("", exclusive: true)
      q.subscribe do |_, _, _|
        delivered = true
      end
      close_all_connections!
      wait_for_recovery_with { connections.any? }
      expect(ch).to be_open

      q.publish("")
      ch.wait_for_confirms

      poll_until { delivered }
    end
  end

  it "recovers all consumers" do
    n = 32

    with_open do |c|
      ch = c.create_channel
      q  = ch.queue("", exclusive: true)
      n.times { q.subscribe { |_, _, _| } }
      close_all_connections!
      wait_for_recovery_with { connections.any? }
      expect(ch).to be_open
      sleep 0.5

      expect(q.consumer_count).to eq n
    end
  end

  it "recovers all queues" do
    n = 32

    qs = []

    with_open do |c|
      ch = c.create_channel

      n.times do
        qs << ch.queue("", exclusive: true)
      end
      close_all_connections!
      wait_for_recovery_with { queue_names.include?(qs.first.name) }
      sleep 0.5
      expect(ch).to be_open

      qs.each do |q|
        ch.queue_declare(q.name, passive: true)
      end
    end
  end

  def exchange_names_in_vhost(vhost)
    http_client.list_exchanges(vhost).map {|e| e["name"]}
  end

  def connections
    http_client.list_connections
  end

  def channels
    http_client.list_channels
  end

  def queue_names
    http_client.list_queues.map {|q| q["name"]}
  end

  def close_all_connections!
    # let whatever actions were taken before
    # this call a chance to propagate, e.g. to make
    # sure that connections are accounted for in the
    # stats DB.
    #
    # See bin/ci/before_build for management plugin
    # pre-configuration.
    #
    # MK.
    sleep 1.1
    connections.each do |conn_info|
      close_ignoring_permitted_exceptions(conn_info.name)
    end
  end

  def close_ignoring_permitted_exceptions(connection_name)
    http_client.close_connection(connection_name)
  rescue Bunny::ConnectionForced, Faraday::ResourceNotFound
    # ignored
  end

  def wait_for_recovery_with(&probe)
    poll_until &probe
  end

  def poll_while(&probe)
    Timeout.timeout(20) {
      sleep 0.1 while probe.call
    }
  end

  def poll_until(&probe)
    Timeout.timeout(20) {
      sleep 0.1 until probe.call
    }
  end

  def with_open(c = Bunny.new(network_recovery_interval: recovery_interval,
                              recover_from_connection_close: true,
                              logger: logger), &block)
    c.start
    block.call(c)
  ensure
    c.close
  end

  def with_open_multi_host(&block)
    c = Bunny.new(hosts: ["127.0.0.1", "localhost"],
                  network_recovery_interval: recovery_interval,
                  recover_from_connection_close: true,
                  logger: logger)
    with_open(c, &block)
  end

  def with_open_multi_broken_host(&block)
    c = Bunny.new(hosts: ["broken", "127.0.0.1", "localhost"],
                  hosts_shuffle_strategy: Proc.new { |hosts| hosts }, # We do not shuffle for these tests so we always hit the broken host
                  network_recovery_interval: recovery_interval,
                  recover_from_connection_close: true,
                  logger: logger)
    with_open(c, &block)
  end

  def ensure_queue_recovery(ch, q)
    ch.confirm_select
    q.purge
    x = ch.default_exchange
    x.publish("msg", routing_key: q.name)
    ch.wait_for_confirms
    expect(q.message_count).to eq 1
    q.purge
  end

  def ensure_queue_binding_recovery(ch, x, q, routing_key = "")
    ch.confirm_select
    q.purge
    x.publish("msg", routing_key: routing_key)
    ch.wait_for_confirms
    expect(q.message_count).to eq 1
    q.purge
  end
end
