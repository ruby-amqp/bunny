require "spec_helper"

describe "A client-named", Bunny::Queue do
  let(:connection) do
    c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed")
    c.start
    c
  end

  it "can be bound to a pre-declared exchange" do
    ch = connection.create_channel
    q  = ch.queue("bunny.tests.queues.client-named#{rand}", :exclusive => true)
    q.should_not be_server_named

    q.bind("amq.fanout").should == q

    ch.close
  end

  it "can be unbound from a pre-declared exchange" do
    ch = connection.create_channel
    q  = ch.queue("bunny.tests.queues.client-named#{rand}", :exclusive => true)
    q.should_not be_server_named

    q.bind("amq.fanout")
    q.unbind("amq.fanout").should == q

    ch.close
  end

  it "can be bound to a custom exchange" do
    ch = connection.create_channel
    q  = ch.queue("bunny.tests.queues.client-named#{rand}", :exclusive => true)

    x  = ch.fanout("bunny.tests.exchanges.fanout#{rand}")
    q.bind(x).should == q

    x.delete
    ch.close
  end

  it "can be unbound from a custom exchange" do
    ch = connection.create_channel
    q  = ch.queue("bunny.tests.queues.client-named#{rand}", :exclusive => true)
    q.should_not be_server_named

    x  = ch.fanout("bunny.tests.fanout", :auto_delete => true, :durable => false)

    q.bind(x)
    q.unbind(x).should == q

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

    q.bind("amq.fanout").should == q

    ch.close
  end

  it "can be unbound from a pre-declared exchange" do
    ch = connection.create_channel
    q  = ch.queue("", :exclusive => true)
    q.should be_server_named

    q.bind("amq.fanout")
    q.unbind("amq.fanout").should == q

    ch.close
  end

  it "can be bound to a custom exchange" do
    ch = connection.create_channel
    q  = ch.queue("", :exclusive => true)

    x  = ch.fanout("bunny.tests.exchanges.fanout#{rand}")
    q.bind(x).should == q

    x.delete
    ch.close
  end

  it "can be bound from a custom exchange" do
    ch   = connection.create_channel
    q    = ch.queue("", :exclusive => true)

    name = "bunny.tests.exchanges.fanout#{rand}"
    x    = ch.fanout(name)
    q.bind(x)
    q.unbind(name).should == q

    x.delete
    ch.close
  end
end
