require "spec_helper"

describe Bunny::TopologyRegistry do
  class ExampleConsumer < Bunny::Consumer
      def call(delivery_info, metadata, payload)
         # no-op
      end
    end

  let(:connection) do
    c = Bunny.new(username: "bunny_gem", password: "bunny_password", vhost: "bunny_testbed")
    c.start
    c
  end
  let(:ch) do
    connection.create_channel
  end

  after :each do
    connection.close if connection.open?
  end

  subject do
    described_class.new
  end

  it "allows a queue to be registered and unregistered" do
    q = ch.durable_queue("bunny.topology_registry.cq.1")

    expect(subject.queues.size).to be ==(0)
    subject.record_queue(q)
    expect(subject.queues.size).to be ==(1)
    subject.delete_queue(q)
    expect(subject.queues.size).to be ==(0)

    q.delete
  end

  it "allows a consumer to be registered and unregistered" do
    q = ch.durable_queue("bunny.topology_registry.cq.2")
    cons = ExampleConsumer.new(ch, q)
    tag = "consumer_tag.32947239847"

    expect(subject.consumers.size).to be ==(0)
    subject.record_consumer(ch, tag, q.name, cons, true, false, {})
    expect(subject.consumers.size).to be ==(1)
    subject.delete_consumer(tag)
    expect(subject.queues.size).to be ==(0)

    q.delete
  end

  it "allows an exchange to be registered and unregistered" do
    x_name = "bunny.topology_registry.x.fanout"
    ch.exchange_delete(x_name)
    x = ch.fanout(x_name, durable: true)

    expect(subject.exchanges.size).to be ==(0)
    subject.record_exchange(x)
    expect(subject.exchanges.size).to be ==(1)
    subject.delete_exchange(x)
    expect(subject.exchanges.size).to be ==(0)

    x.delete
  end

  it "allows an exchange binding to be registered and unregistered" do
    source_name = "bunny.topology_registry.x.fanout"
    dest_name = "bunny.topology_registry.x.topic"

    expect(subject.exchange_bindings.size).to be ==(0)
    subject.record_exchange_binding(ch, source_name, dest_name, "#", {})
    expect(subject.exchange_bindings.size).to be ==(1)
    subject.delete_exchange_binding(ch, source_name, dest_name, "#", {})
    expect(subject.exchanges.size).to be ==(0)

    subject.record_exchange_binding(ch, source_name, dest_name, "#", {})
    expect(subject.exchange_bindings.size).to be ==(1)

    (1..100).to_a.each do |i|
      subject.delete_exchange_binding(ch, source_name, dest_name, "another-rk-#{i}", {})
    end
    expect(subject.exchange_bindings.size).to be ==(1)

    (1..100).to_a.each do |i|
      subject.delete_exchange_binding(ch, "#{source_name}-#{i}", dest_name, "#", {})
    end
    expect(subject.exchange_bindings.size).to be ==(1)

    subject.reset!
  end

  it "allows a queue binding to be registered and unregistered" do
    x_name = "bunny.topology_registry.x.fanout"
    q_name = "bunny.topology_registry.qq.2"

    expect(subject.queue_bindings.size).to be ==(0)
    subject.record_queue_binding(ch, x_name, q_name, "#", {})
    expect(subject.queue_bindings.size).to be ==(1)
    subject.delete_queue_binding(ch, x_name, q_name, "#", {})
    expect(subject.queue_bindings.size).to be ==(0)

    subject.record_queue_binding(ch, x_name, q_name, "#", {})
    expect(subject.queue_bindings.size).to be ==(1)

    (1..100).to_a.each do |i|
      subject.delete_queue_binding(ch, x_name, q_name, "another-rk-#{i}", {})
    end
    expect(subject.queue_bindings.size).to be ==(1)

    (1..100).to_a.each do |i|
      subject.delete_queue_binding(ch, "#{x_name}-#{i}", q_name, "#", {})
    end
    expect(subject.queue_bindings.size).to be ==(1)

    subject.reset!
  end

  it "deletes an auto-delete queue when the last consumer is unregistered" do
    # a deprecated combination but it's optimal for this test
    q = ch.queue("bunny.topology_registry.cq.3", durable: false, exclusive: false, auto_delete: true)

    cons = ExampleConsumer.new(ch, q)
    tag = "consumer_tag.07298594826739847"

    expect(subject.consumers.size).to be ==(0)
    subject.record_consumer(ch, tag, q.name, cons, true, false, {})
    expect(subject.consumers.size).to be ==(1)
    # deleting this consumer deletes its auto_delete queue
    subject.delete_consumer(tag)
    expect(subject.queues.size).to be ==(0)

    q.delete
  end

  it "retains an auto-delete queue that has more consumers" do
    q_name = "bunny.topology_registry.cq.5"
    ch.queue_delete(q_name)
    # a deprecated combination but it's optimal for this test
    q = ch.queue(q_name, durable: false, exclusive: false, auto_delete: true)

    cons1 = ExampleConsumer.new(ch, q)
    tag1 = "consumer_tag.07298594826739847"

    cons2 = ExampleConsumer.new(ch, q)
    tag2 = "consumer_tag.935875983745"

    expect(subject.queues.size).to be ==(0)
    subject.record_queue(q)
    expect(subject.queues.size).to be ==(1)

    expect(subject.consumers.size).to be ==(0)
    subject.record_consumer(ch, tag1, q.name, cons1, true, false, {})
    subject.record_consumer(ch, tag2, q.name, cons2, true, false, {})
    expect(subject.consumers.size).to be ==(2)
    # deleting this consumer should not delete the auto_delete queue
    subject.delete_consumer(tag1)

    expect(subject.queues.size).to be ==(1)
    q.delete
  end

  it "deletes an auto-delete exchange when the last queue is unbound" do
    x_name = "bunny.topology_registry.x.fanout.4"
    ch.exchange_delete(x_name)
    x = ch.fanout(x_name, durable: true, auto_delete: true)
    q_name = "bunny.topology_registry.cq.4"
    ch.queue_delete(q_name)
    q = ch.queue(q_name, durable: true, exclusive: false, auto_delete: false)

    expect(subject.queues.size).to be ==(0)
    subject.record_queue(q)
    expect(subject.queues.size).to be ==(1)

    expect(subject.exchanges.size).to be ==(0)
    subject.record_exchange(x)
    expect(subject.exchanges.size).to be ==(1)

    expect(subject.exchange_bindings.size).to be ==(0)
    subject.record_exchange_binding(ch, x.name, q.name, "#", {})
    expect(subject.exchange_bindings.size).to be ==(1)

    subject.delete_exchange_binding(ch, x.name, q.name, "#", {})
    expect(subject.exchanges.size).to be ==(0)

    x.delete
    q.delete
  end

  it "retains an auto-delete exchange when more (exchange) bindings are present" do
    x1_name = "bunny.topology_registry.x.fanout.5"
    ch.exchange_delete(x1_name)
    x2_name = "bunny.topology_registry.x.fanout.6"
    ch.exchange_delete(x2_name)
    x1 = ch.fanout(x1_name, durable: true, auto_delete: true)
    x2 = ch.fanout(x2_name, durable: true, auto_delete: false)
    q_name = "bunny.topology_registry.cq.4"
    ch.queue_delete(q_name)
    q = ch.queue(q_name, durable: true, exclusive: false, auto_delete: false)

    expect(subject.queues.size).to be ==(0)
    subject.record_queue(q)
    expect(subject.queues.size).to be ==(1)

    expect(subject.exchanges.size).to be ==(0)
    subject.record_exchange(x1)
    subject.record_exchange(x2)
    expect(subject.exchanges.size).to be ==(2)

    expect(subject.exchange_bindings.size).to be ==(0)
    subject.record_exchange_binding(ch, x1.name, q.name, "#", {})
    subject.record_exchange_binding(ch, x1.name, x2.name, "#", {})
    expect(subject.exchange_bindings.size).to be ==(2)

    subject.delete_exchange_binding(ch, x1.name, q.name, "#", {})
    expect(subject.exchanges.size).to be ==(2)

    subject.delete_exchange_binding(ch, x1.name, x2.name, "#", {})
    expect(subject.exchanges.size).to be ==(1)

    x1.delete
    x2.delete
    q.delete
  end

  it "retains an auto-delete exchange when more (queue) bindings are present" do
    x_name = "bunny.topology_registry.x.fanout.7"
    ch.exchange_delete(x_name)
    x = ch.fanout(x_name, durable: true, auto_delete: true)

    q1_name = "bunny.topology_registry.cq.5"
    ch.queue_delete(q1_name)
    q1 = ch.queue(q1_name, durable: true, exclusive: false, auto_delete: false)

    q2_name = "bunny.topology_registry.cq.6"
    ch.queue_delete(q2_name)
    q2 = ch.queue(q2_name, durable: true, exclusive: false, auto_delete: false)

    expect(subject.queues.size).to be ==(0)
    subject.record_queue(q1)
    subject.record_queue(q2)
    expect(subject.queues.size).to be ==(2)

    expect(subject.exchanges.size).to be ==(0)
    subject.record_exchange(x)
    expect(subject.exchanges.size).to be ==(1)

    expect(subject.exchange_bindings.size).to be ==(0)
    subject.record_exchange_binding(ch, x.name, q1.name, "#", {})
    subject.record_exchange_binding(ch, x.name, q2.name, "#", {})
    expect(subject.exchange_bindings.size).to be ==(2)

    expect(subject.exchanges.size).to be ==(1)
    subject.delete_exchange_binding(ch, x.name, q1.name, "#", {})
    expect(subject.exchanges.size).to be ==(1)

    subject.delete_exchange_binding(ch, x.name, q2.name, "#", {})
    expect(subject.exchanges.size).to be ==(0)

    q1.delete
    q2.delete
    x.delete
  end

  it "removes queue bindings when their exchange is removed" do
    x_name = "bunny.topology_registry.x.fanout.8"
    ch.exchange_delete(x_name)
    x = ch.fanout(x_name, durable: true, auto_delete: true)

    q1_name = "bunny.topology_registry.cq.6"
    ch.queue_delete(q1_name)
    q1 = ch.queue(q1_name, durable: true, exclusive: false, auto_delete: false)

    q2_name = "bunny.topology_registry.cq.7"
    ch.queue_delete(q2_name)
    q2 = ch.queue(q2_name, durable: true, exclusive: false, auto_delete: false)

    expect(subject.queues.size).to be ==(0)
    subject.record_queue(q1)
    subject.record_queue(q2)
    expect(subject.queues.size).to be ==(2)

    expect(subject.exchanges.size).to be ==(0)
    subject.record_exchange(x)
    expect(subject.exchanges.size).to be ==(1)

    expect(subject.queue_bindings.size).to be ==(0)
    subject.record_queue_binding(ch, x.name, q1.name, "#", {})
    subject.record_queue_binding(ch, x.name, q2.name, "#", {})
    expect(subject.queue_bindings.size).to be ==(2)

    subject.delete_exchange_named(x_name)
    expect(subject.queue_bindings.size).to be ==(0)

    q1.delete
    q2.delete
    x.delete
  end

  it "removes queue bindings when their queue is removed" do
    x_name = "bunny.topology_registry.x.fanout.0"
    ch.exchange_delete(x_name)
    x = ch.fanout(x_name, durable: true, auto_delete: true)

    q1_name = "bunny.topology_registry.cq.8"
    ch.queue_delete(q1_name)
    q1 = ch.queue(q1_name, durable: true, exclusive: false, auto_delete: false)

    q2_name = "bunny.topology_registry.cq.9"
    ch.queue_delete(q2_name)
    q2 = ch.queue(q2_name, durable: true, exclusive: false, auto_delete: false)

    subject.record_queue(q1)
    subject.record_queue(q2)
    expect(subject.queues.size).to be ==(2)

    subject.record_exchange(x)
    expect(subject.exchanges.size).to be ==(1)

    expect(subject.queue_bindings.size).to be ==(0)
    subject.record_queue_binding(ch, x.name, q1.name, "#", {})
    subject.record_queue_binding(ch, x.name, q2.name, "#", {})
    expect(subject.queue_bindings.size).to be ==(2)


    subject.delete_queue_named(q1_name)
    expect(subject.queue_bindings.size).to be ==(1)

    subject.delete_queue_named(q2_name)
    expect(subject.queue_bindings.size).to be ==(0)

    q1.delete
    q2.delete
    x.delete
  end

  it "removes exchange bindings when their source exchange is removed" do
    x1_name = "bunny.topology_registry.x.fanout.8"
    ch.exchange_delete(x1_name)
    x1 = ch.fanout(x1_name, durable: true, auto_delete: true)

    x2_name = "bunny.topology_registry.x.fanout.9"
    ch.exchange_delete(x2_name)
    x2 = ch.fanout(x2_name, durable: true, auto_delete: true)

    x3_name = "bunny.topology_registry.x.fanout.10"
    ch.exchange_delete(x3_name)
    x3 = ch.fanout(x3_name, durable: true, auto_delete: true)

    expect(subject.exchanges.size).to be ==(0)
    subject.record_exchange(x1)
    subject.record_exchange(x2)
    subject.record_exchange(x3)
    expect(subject.exchanges.size).to be ==(3)

    expect(subject.exchange_bindings.size).to be ==(0)
    subject.record_exchange_binding(ch, x1.name, x2.name, "#", {})
    subject.record_exchange_binding(ch, x1.name, x3.name, "#", {})
    expect(subject.exchange_bindings.size).to be ==(2)

    subject.delete_exchange_named(rand.to_s)
    expect(subject.exchange_bindings.size).to be ==(2)

    subject.delete_exchange_named(x1_name)
    expect(subject.exchange_bindings.size).to be ==(0)

    x1.delete
    x2.delete
    x3.delete
  end

  it "removes exchange bindings when their destination exchange is removed" do
    x1_name = "bunny.topology_registry.x.fanout.11"
    ch.exchange_delete(x1_name)
    x1 = ch.fanout(x1_name, durable: true, auto_delete: true)

    x2_name = "bunny.topology_registry.x.fanout.12"
    ch.exchange_delete(x2_name)
    x2 = ch.fanout(x2_name, durable: true, auto_delete: true)

    x3_name = "bunny.topology_registry.x.fanout.13"
    ch.exchange_delete(x3_name)
    x3 = ch.fanout(x3_name, durable: true, auto_delete: true)

    expect(subject.exchanges.size).to be ==(0)
    subject.record_exchange(x1)
    subject.record_exchange(x2)
    subject.record_exchange(x3)
    expect(subject.exchanges.size).to be ==(3)

    expect(subject.exchange_bindings.size).to be ==(0)
    subject.record_exchange_binding(ch, x1.name, x2.name, "#", {})
    subject.record_exchange_binding(ch, x1.name, x3.name, "#", {})
    expect(subject.exchange_bindings.size).to be ==(2)

    subject.delete_exchange_named(rand.to_s)
    expect(subject.exchange_bindings.size).to be ==(2)

    subject.delete_exchange_named(x2_name)
    expect(subject.exchange_bindings.size).to be ==(1)

    subject.delete_exchange_named(x3_name)
    expect(subject.exchange_bindings.size).to be ==(0)

    x1.delete
    x2.delete
    x3.delete
  end
end