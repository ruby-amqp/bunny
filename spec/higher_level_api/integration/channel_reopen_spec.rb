require "spec_helper"

describe Bunny::Channel, "#reopen" do
  let(:connection) do
    c = Bunny.new(username: "bunny_gem", password: "bunny_password", vhost: "bunny_testbed")
    c.start
    c
  end

  after :each do
    connection.close if connection.open?
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

  context "with recover_channel_topology" do
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
