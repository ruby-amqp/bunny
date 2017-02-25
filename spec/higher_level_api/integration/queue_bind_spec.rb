require "spec_helper"

describe "A client-named", Bunny::Queue do
  let(:connection) do
    c = Bunny.new(username: "bunny_gem", password: "bunny_password", vhost: "bunny_testbed")
    c.start
    c
  end

  it "can be bound to a pre-declared exchange" do
    ch = connection.create_channel
    q  = ch.queue("bunny.tests.queues.client-named#{rand}", exclusive: true)
    expect(q).not_to be_server_named

    expect(q.bind("amq.fanout")).to eq q

    ch.close
  end

  it "can be unbound from a pre-declared exchange" do
    ch = connection.create_channel
    q  = ch.queue("bunny.tests.queues.client-named#{rand}", exclusive: true)
    expect(q).not_to be_server_named

    q.bind("amq.fanout")
    expect(q.unbind("amq.fanout")).to eq q

    ch.close
  end

  it "can be bound to a custom exchange" do
    ch = connection.create_channel
    q  = ch.queue("bunny.tests.queues.client-named#{rand}", exclusive: true)

    x  = ch.fanout("bunny.tests.exchanges.fanout#{rand}")
    expect(q.bind(x)).to eq q

    x.delete
    ch.close
  end

  it "can be unbound from a custom exchange" do
    ch = connection.create_channel
    q  = ch.queue("bunny.tests.queues.client-named#{rand}", exclusive: true)
    expect(q).not_to be_server_named

    x  = ch.fanout("bunny.tests.fanout", auto_delete: true, durable: false)

    q.bind(x)
    expect(q.unbind(x)).to eq q

    ch.close
  end
end



describe "A server-named", Bunny::Queue do
  let(:connection) do
    c = Bunny.new
    c.start
    c
  end

  it "can be bound to a pre-declared exchange" do
    ch = connection.create_channel
    q  = ch.queue("", exclusive: true)
    expect(q).to be_server_named

    expect(q.bind("amq.fanout")).to eq q

    ch.close
  end

  it "can be unbound from a pre-declared exchange" do
    ch = connection.create_channel
    q  = ch.queue("", exclusive: true)
    expect(q).to be_server_named

    q.bind("amq.fanout")
    expect(q.unbind("amq.fanout")).to eq q

    ch.close
  end

  it "can be bound to a custom exchange" do
    ch = connection.create_channel
    q  = ch.queue("", exclusive: true)

    x  = ch.fanout("bunny.tests.exchanges.fanout#{rand}")
    expect(q.bind(x)).to eq q

    x.delete
    ch.close
  end

  it "can be bound from a custom exchange" do
    ch   = connection.create_channel
    q    = ch.queue("", exclusive: true)

    name = "bunny.tests.exchanges.fanout#{rand}"
    x    = ch.fanout(name)
    q.bind(x)
    expect(q.unbind(name)).to eq q

    x.delete
    ch.close
  end
end
