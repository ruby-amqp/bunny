require "spec_helper"

describe "A client-named", Bunny::Queue do
  let(:connection) do
    c = Bunny.new
    c.start
    c
  end

  it "can be bound to a pre-declared exchange" do
    ch = connection.create_channel
    q  = ch.queue("bunny.tests.queues.client-named1", :exclusive => true)
    q.should_not be_server_named

    q.bind("amq.fanout").should be_instance_of(AMQ::Protocol::Queue::BindOk)

    ch.close
  end

  it "can be bound to a custom exchange" do
    ch = connection.create_channel
    q  = ch.queue("bunny.tests.queues.client-named2", :exclusive => true)

    x  = ch.fanout("bunny.tests.exchanges.fanout1")
    q.bind(x).should be_instance_of(AMQ::Protocol::Queue::BindOk)

    x.delete
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

  it "can be bound to a custom exchange" do
    ch = connection.create_channel
    q  = ch.queue("", :exclusive => true)

    x  = ch.fanout("bunny.tests.exchanges.fanout2")
    q.bind(x).should be_instance_of(AMQ::Protocol::Queue::BindOk)

    x.delete
    ch.close
  end
end
