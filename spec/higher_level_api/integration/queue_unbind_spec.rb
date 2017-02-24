require "spec_helper"

describe Bunny::Queue, "bound to an exchange" do
  let(:connection) do
    c = Bunny.new(username: "bunny_gem", password: "bunny_password", vhost: "bunny_testbed")
    c.start
    c
  end

  after :each do
    connection.close
  end


  it "can be unbound from an exchange it was bound to" do
    ch = connection.create_channel
    x  = ch.fanout("amq.fanout")
    q  = ch.queue("", exclusive: true).bind(x)

    x.publish("")
    sleep 0.3
    expect(q.message_count).to eq 1

    q.unbind(x)

    x.publish("")
    expect(q.message_count).to eq 1
  end
end



describe Bunny::Queue, "NOT bound to an exchange" do
  let(:connection) do
    c = Bunny.new(username: "bunny_gem", password: "bunny_password", vhost: "bunny_testbed")
    c.start
    c
  end

  after :each do
    connection.close
  end


  it "is idempotent (succeeds)" do
    ch = connection.create_channel
    x  = ch.fanout("amq.fanout")
    q  = ch.queue("", exclusive: true)

    # No exception as of RabbitMQ 3.2. MK.
    q.unbind(x)
    q.unbind(x)
  end
end
