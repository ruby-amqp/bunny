require "spec_helper"
require "bunny/concurrent/condition"

describe Bunny::Channel, "#reopen" do
  let(:connection) do
    c = Bunny.new(username: "bunny_gem", password: "bunny_password", vhost: "bunny_testbed")
    c.start
    c
  end

  after :each do
    connection.close if connection.open?
  end

  it "can reopen a channel directly inside on_error" do
    ch = connection.create_channel
    done = Bunny::Concurrent::Condition.new

    ch.on_error do |closed_ch, amq_close|
      closed_ch.reopen
      done.notify
    end

    ch.ack(82, false)
    done.wait
    expect(ch).to be_open

    q = ch.queue("bunny.test.channel-reopen.on-error.#{rand}", exclusive: true)
    ch.default_exchange.publish("hello", routing_key: q.name)
    sleep 0.25
    expect(q.message_count).to eq 1
  end

  it "reopens a channel after a server-initiated closure" do
    ch = connection.create_channel
    q  = ch.queue("bunny.test.channel-reopen.#{rand}", exclusive: true)

    ch.on_error do |closed_ch, amq_close|
      @channel_close = amq_close
    end

    # ack with an invalid tag to force a 406 channel closure
    ch.ack(82, false)
    sleep 0.25

    expect(@channel_close.reply_code).to eq AMQ::Protocol::PreconditionFailed::VALUE
    expect(@channel_close).to be_unknown_delivery_tag
    expect(@channel_close).not_to be_delivery_ack_timeout
    expect(ch).to be_closed

    ch.reopen
    expect(ch).to be_open

    # the channel should be functional again
    q2 = ch.queue("bunny.test.channel-reopen.after.#{rand}", exclusive: true)
    ch.default_exchange.publish("hello", routing_key: q2.name)
    sleep 0.25
    expect(q2.message_count).to eq 1
  end

  it "recovers prefetch setting after reopen" do
    ch = connection.create_channel
    ch.prefetch(5)

    ch.on_error do |_, _| end

    ch.ack(82, false)
    sleep 0.25
    expect(ch).to be_closed

    ch.reopen
    expect(ch).to be_open
    expect(ch.prefetch_count).to eq 5
  end

  it "raises when called on a channel that is still open" do
    ch = connection.create_channel
    expect { ch.reopen }.to raise_error(RuntimeError, /not closed/)
  end

  it "recovers publisher confirm mode after reopen" do
    ch = connection.create_channel
    ch.confirm_select(tracking: true, outstanding_limit: 42)

    ch.ack(82, false)
    sleep 0.25
    expect(ch).to be_closed

    ch.reopen
    expect(ch).to be_open
    expect(ch).to be_using_publisher_confirmations

    q = ch.queue("bunny.test.channel-reopen.confirms.#{rand}", exclusive: true)
    ch.basic_publish("hello", "", q.name)
    ch.wait_for_confirms

    expect(q.message_count).to eq 1
  end

  context "with recover_channel_topology" do
    it "drops acknowledgements for deliveries from before the reopen" do
      ch = connection.create_channel
      ch.prefetch(10)
      q  = ch.queue("bunny.test.channel-reopen.stale-tags.#{rand}", exclusive: true)

      deliveries = Queue.new
      q.subscribe(manual_ack: true) { |di, _props, payload| deliveries << [di.delivery_tag, payload] }

      closures = Queue.new
      ch.on_error do |closed_ch, amq_close|
        closed_ch.reopen
        connection.recover_channel_topology(closed_ch)
        closures << amq_close
      end

      3.times { |i| ch.default_exchange.publish("m#{i}", routing_key: q.name) }
      before = Array.new(3) { deliveries.pop(timeout: 5) }
      expect(before.map(&:first)).to eq [1, 2, 3]

      # force a closure, RabbitMQ requeues the three deliveries
      ch.ack(999, false)
      expect(closures.pop(timeout: 5)).to be_unknown_delivery_tag
      after = Array.new(3) { deliveries.pop(timeout: 5) }
      expect(after.map(&:first)).to eq [4, 5, 6]

      before.each { |tag, _| ch.ack(tag) }
      after.each { |tag, _| ch.ack(tag) }

      # a basic.get round trip makes sure the server has processed the acknowledgements
      expect(ch.basic_get(q.name, manual_ack: false).first).to be_nil
      expect(closures).to be_empty
      expect(ch).to be_open

      ch.close
      expect(connection.create_channel.queue(q.name, passive: true).message_count).to eq 0
    end

    it "does not leak a consumer work pool on reopen" do
      ch = connection.create_channel
      q  = ch.queue("bunny.test.channel-reopen.work-pool.#{rand}", exclusive: true)
      q.subscribe(manual_ack: true) { |_, _, _| }

      reopened = Queue.new
      ch.on_error do |closed_ch, _|
        closed_ch.reopen
        pool = closed_ch.work_pool
        connection.recover_channel_topology(closed_ch)
        reopened << pool
      end

      ch.ack(999, false)
      pool = reopened.pop(timeout: 5)

      # topology recovery used to replace the pool #reopen had started, and nothing stopped its thread
      expect(ch.work_pool).to equal(pool)
    end

    it "re-registers consumers that receive new messages" do
      ch = connection.create_channel
      ch.prefetch(1)
      q  = ch.queue("bunny.test.channel-reopen.topology.#{rand}", exclusive: true)
      x  = ch.default_exchange

      delivered = []
      q.subscribe(manual_ack: true) do |di, _props, payload|
        delivered << payload
        ch.ack(di.delivery_tag)
      end

      x.publish("before", routing_key: q.name)
      sleep 0.5
      expect(delivered).to eq ["before"]

      ch.on_error do |_, _| end

      # force channel closure
      ch.ack(999, false)
      sleep 0.25
      expect(ch).to be_closed

      ch.reopen
      connection.recover_channel_topology(ch)
      sleep 0.25

      x.publish("after", routing_key: q.name)
      sleep 0.5
      expect(delivered).to include("after")
    end
  end
end
