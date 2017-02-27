require "spec_helper"

describe "A message" do
  let(:connection) do
    c = Bunny.new(username: "bunny_gem", password: "bunny_password", vhost: "bunny_testbed")
    c.start
    c
  end

  after :each do
    connection.close if connection.open?
  end

  it "is considered to be dead-lettered when it is rejected without requeueing" do
    ch   = connection.create_channel
    x    = ch.fanout("amq.fanout")
    dlx  = ch.fanout("bunny.tests.dlx.exchange")
    q    = ch.queue("", exclusive: true, arguments: {"x-dead-letter-exchange" => dlx.name}).bind(x)
    # dead letter queue
    dlq  = ch.queue("", exclusive: true).bind(dlx)

    x.publish("")
    sleep 0.2

    delivery_info, _, _ = q.pop(manual_ack: true)
    expect(dlq.message_count).to be_zero
    ch.nack(delivery_info.delivery_tag)

    sleep 0.2
    expect(q.message_count).to be_zero

    delivery, properties, body = dlq.pop
    ds = properties.headers["x-death"]
    expect(ds).not_to be_empty
    expect(ds.first["reason"]).to eq("rejected")

    dlx.delete
  end

  it "is considered to be dead-lettered when it expires" do
    ch   = connection.create_channel
    x    = ch.fanout("amq.fanout")
    dlx  = ch.fanout("bunny.tests.dlx.exchange")
    q    = ch.queue("", exclusive: true, arguments: {"x-dead-letter-exchange" => dlx.name, "x-message-ttl" => 100}).bind(x)
    # dead letter queue
    dlq  = ch.queue("", exclusive: true).bind(dlx)

    x.publish("")
    sleep 0.2

    expect(q.message_count).to be_zero
    expect(dlq.message_count).to eq 1

    dlx.delete
  end

  it "carries the x-death header" do
    ch   = connection.create_channel
    x    = ch.fanout("amq.fanout")
    dlx  = ch.fanout("bunny.tests.dlx.exchange")
    q    = ch.queue("", exclusive: true, arguments: {"x-dead-letter-exchange" => dlx.name, "x-message-ttl" => 100}).bind(x)
    # dead letter queue
    dlq  = ch.queue("", exclusive: true).bind(dlx)

    x.publish("")
    sleep 0.2

    delivery, properties, body = dlq.pop
    ds = properties.headers["x-death"]
    expect(ds).not_to be_empty
    expect(ds.first["reason"]).to eq("expired")

    dlx.delete
  end
end
