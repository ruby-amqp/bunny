require "spec_helper"

describe "A client-named", Bunny::Queue do
  let(:connection) do
    c = Bunny.new
    c.start
    c
  end

  it "can be bound to a pre-declared exchange" do
    ch = connection.create_channel
    q  = ch.queue("bunny.tests.queues.client-named#{rand}", :exclusive => true)
    q.should_not be_server_named

    q.bind("amq.fanout").should be_instance_of(AMQ::Protocol::Queue::BindOk)

    ch.close
  end

  it "can be unbound from a pre-declared exchange" do
    ch = connection.create_channel
    q  = ch.queue("bunny.tests.queues.client-named#{rand}", :exclusive => true)
    q.should_not be_server_named

    q.bind("amq.fanout")
    q.unbind("amq.fanout").should be_instance_of(AMQ::Protocol::Queue::UnbindOk)

    ch.close
  end

  it "can be bound to a custom exchange" do
    ch = connection.create_channel
    q  = ch.queue("bunny.tests.queues.client-named#{rand}", :exclusive => true)

    x  = ch.fanout("bunny.tests.exchanges.fanout#{rand}")
    q.bind(x).should be_instance_of(AMQ::Protocol::Queue::BindOk)

    x.delete
    ch.close
  end

  it "can be unbound from a custom exchange" do
    ch = connection.create_channel
    q  = ch.queue("bunny.tests.queues.client-named#{rand}", :exclusive => true)
    q.should_not be_server_named

    x  = ch.fanout("bunny.tests.fanout", :auto_delete => true, :durable => false)

    q.bind(x)
    q.unbind(x).should be_instance_of(AMQ::Protocol::Queue::UnbindOk)

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
    q  = ch.queue("", :exclusive => true)
    q.should be_server_named

    q.bind("amq.fanout").should be_instance_of(AMQ::Protocol::Queue::BindOk)

    ch.close
  end

  it "can be unbound from a pre-declared exchange" do
    ch = connection.create_channel
    q  = ch.queue("", :exclusive => true)
    q.should be_server_named

    q.bind("amq.fanout")
    q.unbind("amq.fanout").should be_instance_of(AMQ::Protocol::Queue::UnbindOk)

    ch.close
  end

  it "can be bound to a custom exchange" do
    ch = connection.create_channel
    q  = ch.queue("", :exclusive => true)

    x  = ch.fanout("bunny.tests.exchanges.fanout#{rand}")
    q.bind(x).should be_instance_of(AMQ::Protocol::Queue::BindOk)

    x.delete
    ch.close
  end

  it "can be bound from a custom exchange" do
    ch   = connection.create_channel
    q    = ch.queue("", :exclusive => true)

    name = "bunny.tests.exchanges.fanout#{rand}"
    x    = ch.fanout(name)
    q.bind(x)
    q.unbind(name).should be_instance_of(AMQ::Protocol::Queue::UnbindOk)

    x.delete
    ch.close
  end
end
