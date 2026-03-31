# -*- coding: utf-8 -*-
# frozen_string_literal: true
require "spec_helper"

describe Bunny::TopologyRegistry do
  # These tests use the _with methods which accept primitive values,
  # so no real connection is needed. The channel parameter is stored
  # but not used by the registry itself.
  let(:ch) { nil }

  subject do
    described_class.new
  end

  it "allows a queue to be registered and unregistered" do
    q_name = "bunny.topology_registry.cq.1"

    expect(subject.queues.size).to be ==(0)
    subject.record_queue_with(ch, q_name, false, true, false, false, {})
    expect(subject.queues.size).to be ==(1)
    subject.delete_recorded_queue_named(q_name)
    expect(subject.queues.size).to be ==(0)
  end

  it "allows a consumer to be registered and unregistered" do
    q_name = "bunny.topology_registry.cq.2"
    tag = "consumer_tag.32947239847"
    callable = proc { |*args| args }

    expect(subject.consumers.size).to be ==(0)
    subject.record_consumer_with(ch, tag, q_name, callable, true, false, {})
    expect(subject.consumers.size).to be ==(1)
    subject.delete_recorded_consumer(tag)
    expect(subject.queues.size).to be ==(0)
  end

  it "allows an exchange to be registered and unregistered" do
    x_name = "bunny.topology_registry.x.fanout"

    expect(subject.exchanges.size).to be ==(0)
    subject.record_exchange_with(ch, x_name, :fanout, true, false, {})
    expect(subject.exchanges.size).to be ==(1)
    subject.delete_recorded_exchange_named(x_name)
    expect(subject.exchanges.size).to be ==(0)
  end

  it "allows an exchange binding to be registered and unregistered" do
    source_name = "bunny.topology_registry.x.fanout"
    dest_name = "bunny.topology_registry.x.topic"

    expect(subject.exchange_bindings.size).to be ==(0)
    subject.record_exchange_binding_with(ch, source_name, dest_name, "#", {})
    expect(subject.exchange_bindings.size).to be ==(1)
    subject.delete_recorded_exchange_binding(ch, source_name, dest_name, "#", {})
    expect(subject.exchanges.size).to be ==(0)

    subject.record_exchange_binding_with(ch, source_name, dest_name, "#", {})
    expect(subject.exchange_bindings.size).to be ==(1)

    (1..100).to_a.each do |i|
      subject.delete_recorded_exchange_binding(ch, source_name, dest_name, "another-rk-#{i}", {})
    end
    expect(subject.exchange_bindings.size).to be ==(1)

    (1..100).to_a.each do |i|
      subject.delete_recorded_exchange_binding(ch, "#{source_name}-#{i}", dest_name, "#", {})
    end
    expect(subject.exchange_bindings.size).to be ==(1)

    subject.reset!
  end

  it "allows a queue binding to be registered and unregistered" do
    x_name = "bunny.topology_registry.x.fanout"
    q_name = "bunny.topology_registry.qq.2"

    expect(subject.queue_bindings.size).to be ==(0)
    subject.record_queue_binding_with(ch, x_name, q_name, "#", {})
    expect(subject.queue_bindings.size).to be ==(1)
    subject.delete_recorded_queue_binding(ch, x_name, q_name, "#", {})
    expect(subject.queue_bindings.size).to be ==(0)

    subject.record_queue_binding_with(ch, x_name, q_name, "#", {})
    expect(subject.queue_bindings.size).to be ==(1)

    (1..100).to_a.each do |i|
      subject.delete_recorded_queue_binding(ch, x_name, q_name, "another-rk-#{i}", {})
    end
    expect(subject.queue_bindings.size).to be ==(1)

    (1..100).to_a.each do |i|
      subject.delete_recorded_queue_binding(ch, "#{x_name}-#{i}", q_name, "#", {})
    end
    expect(subject.queue_bindings.size).to be ==(1)

    subject.reset!
  end

  it "deletes an auto-delete queue when the last consumer is unregistered" do
    q_name = "bunny.topology_registry.cq.3"
    tag = "consumer_tag.07298594826739847"
    callable = proc { |*args| args }

    # Record an auto-delete queue
    subject.record_queue_with(ch, q_name, false, false, true, false, {})

    expect(subject.consumers.size).to be ==(0)
    subject.record_consumer_with(ch, tag, q_name, callable, true, false, {})
    expect(subject.consumers.size).to be ==(1)
    # deleting this consumer deletes its auto_delete queue
    subject.delete_recorded_consumer(tag)
    expect(subject.queues.size).to be ==(0)
  end

  it "retains an auto-delete queue that has more consumers" do
    q_name = "bunny.topology_registry.cq.5"
    tag1 = "consumer_tag.07298594826739847"
    tag2 = "consumer_tag.935875983745"
    callable = proc { |*args| args }

    expect(subject.queues.size).to be ==(0)
    # Record an auto-delete queue
    subject.record_queue_with(ch, q_name, false, false, true, false, {})
    expect(subject.queues.size).to be ==(1)

    expect(subject.consumers.size).to be ==(0)
    subject.record_consumer_with(ch, tag1, q_name, callable, true, false, {})
    subject.record_consumer_with(ch, tag2, q_name, callable, true, false, {})
    expect(subject.consumers.size).to be ==(2)
    # deleting this consumer should not delete the auto_delete queue
    subject.delete_recorded_consumer(tag1)

    expect(subject.queues.size).to be ==(1)
  end

  it "deletes an auto-delete exchange when the last queue is unbound" do
    x_name = "bunny.topology_registry.x.fanout.4"
    q_name = "bunny.topology_registry.cq.4"

    expect(subject.queues.size).to be ==(0)
    subject.record_queue_with(ch, q_name, false, true, false, false, {})
    expect(subject.queues.size).to be ==(1)

    expect(subject.exchanges.size).to be ==(0)
    # Record an auto-delete exchange
    subject.record_exchange_with(ch, x_name, :fanout, true, true, {})
    expect(subject.exchanges.size).to be ==(1)

    expect(subject.exchange_bindings.size).to be ==(0)
    subject.record_exchange_binding_with(ch, x_name, q_name, "#", {})
    expect(subject.exchange_bindings.size).to be ==(1)

    subject.delete_recorded_exchange_binding(ch, x_name, q_name, "#", {})
    expect(subject.exchanges.size).to be ==(0)
  end

  it "retains an auto-delete exchange when more (exchange) bindings are present" do
    x1_name = "bunny.topology_registry.x.fanout.5"
    x2_name = "bunny.topology_registry.x.fanout.6"
    q_name = "bunny.topology_registry.cq.4"

    expect(subject.queues.size).to be ==(0)
    subject.record_queue_with(ch, q_name, false, true, false, false, {})
    expect(subject.queues.size).to be ==(1)

    expect(subject.exchanges.size).to be ==(0)
    # x1 is auto-delete, x2 is not
    subject.record_exchange_with(ch, x1_name, :fanout, true, true, {})
    subject.record_exchange_with(ch, x2_name, :fanout, true, false, {})
    expect(subject.exchanges.size).to be ==(2)

    expect(subject.exchange_bindings.size).to be ==(0)
    subject.record_exchange_binding_with(ch, x1_name, q_name, "#", {})
    subject.record_exchange_binding_with(ch, x1_name, x2_name, "#", {})
    expect(subject.exchange_bindings.size).to be ==(2)

    subject.delete_recorded_exchange_binding(ch, x1_name, q_name, "#", {})
    expect(subject.exchanges.size).to be ==(2)

    subject.delete_recorded_exchange_binding(ch, x1_name, x2_name, "#", {})
    expect(subject.exchanges.size).to be ==(1)
  end

  it "retains an auto-delete exchange when more (queue) bindings are present" do
    x_name = "bunny.topology_registry.x.fanout.7"
    q1_name = "bunny.topology_registry.cq.5"
    q2_name = "bunny.topology_registry.cq.6"

    expect(subject.queues.size).to be ==(0)
    subject.record_queue_with(ch, q1_name, false, true, false, false, {})
    subject.record_queue_with(ch, q2_name, false, true, false, false, {})
    expect(subject.queues.size).to be ==(2)

    expect(subject.exchanges.size).to be ==(0)
    # auto-delete exchange
    subject.record_exchange_with(ch, x_name, :fanout, true, true, {})
    expect(subject.exchanges.size).to be ==(1)

    expect(subject.exchange_bindings.size).to be ==(0)
    subject.record_exchange_binding_with(ch, x_name, q1_name, "#", {})
    subject.record_exchange_binding_with(ch, x_name, q2_name, "#", {})
    expect(subject.exchange_bindings.size).to be ==(2)

    expect(subject.exchanges.size).to be ==(1)
    subject.delete_recorded_exchange_binding(ch, x_name, q1_name, "#", {})
    expect(subject.exchanges.size).to be ==(1)

    subject.delete_recorded_exchange_binding(ch, x_name, q2_name, "#", {})
    expect(subject.exchanges.size).to be ==(0)
  end

  it "removes queue bindings when their exchange is removed" do
    x_name = "bunny.topology_registry.x.fanout.8"
    q1_name = "bunny.topology_registry.cq.6"
    q2_name = "bunny.topology_registry.cq.7"

    expect(subject.queues.size).to be ==(0)
    subject.record_queue_with(ch, q1_name, false, true, false, false, {})
    subject.record_queue_with(ch, q2_name, false, true, false, false, {})
    expect(subject.queues.size).to be ==(2)

    expect(subject.exchanges.size).to be ==(0)
    subject.record_exchange_with(ch, x_name, :fanout, true, true, {})
    expect(subject.exchanges.size).to be ==(1)

    expect(subject.queue_bindings.size).to be ==(0)
    subject.record_queue_binding_with(ch, x_name, q1_name, "#", {})
    subject.record_queue_binding_with(ch, x_name, q2_name, "#", {})
    expect(subject.queue_bindings.size).to be ==(2)

    subject.delete_recorded_exchange_named(x_name)
    expect(subject.queue_bindings.size).to be ==(0)
  end

  it "removes queue bindings when their queue is removed" do
    x_name = "bunny.topology_registry.x.fanout.0"
    q1_name = "bunny.topology_registry.cq.8"
    q2_name = "bunny.topology_registry.cq.9"

    subject.record_queue_with(ch, q1_name, false, true, false, false, {})
    subject.record_queue_with(ch, q2_name, false, true, false, false, {})
    expect(subject.queues.size).to be ==(2)

    subject.record_exchange_with(ch, x_name, :fanout, true, true, {})
    expect(subject.exchanges.size).to be ==(1)

    expect(subject.queue_bindings.size).to be ==(0)
    subject.record_queue_binding_with(ch, x_name, q1_name, "#", {})
    subject.record_queue_binding_with(ch, x_name, q2_name, "#", {})
    expect(subject.queue_bindings.size).to be ==(2)


    subject.delete_recorded_queue_named(q1_name)
    expect(subject.queue_bindings.size).to be ==(1)

    subject.delete_recorded_queue_named(q2_name)
    expect(subject.queue_bindings.size).to be ==(0)
  end

  it "removes exchange bindings when their source exchange is removed" do
    x1_name = "bunny.topology_registry.x.fanout.8"
    x2_name = "bunny.topology_registry.x.fanout.9"
    x3_name = "bunny.topology_registry.x.fanout.10"

    expect(subject.exchanges.size).to be ==(0)
    subject.record_exchange_with(ch, x1_name, :fanout, true, true, {})
    subject.record_exchange_with(ch, x2_name, :fanout, true, true, {})
    subject.record_exchange_with(ch, x3_name, :fanout, true, true, {})
    expect(subject.exchanges.size).to be ==(3)

    expect(subject.exchange_bindings.size).to be ==(0)
    subject.record_exchange_binding_with(ch, x1_name, x2_name, "#", {})
    subject.record_exchange_binding_with(ch, x1_name, x3_name, "#", {})
    expect(subject.exchange_bindings.size).to be ==(2)

    subject.delete_recorded_exchange_named(rand.to_s)
    expect(subject.exchange_bindings.size).to be ==(2)

    subject.delete_recorded_exchange_named(x1_name)
    expect(subject.exchange_bindings.size).to be ==(0)
  end

  it "removes exchange bindings when their destination exchange is removed" do
    x1_name = "bunny.topology_registry.x.fanout.11"
    x2_name = "bunny.topology_registry.x.fanout.12"
    x3_name = "bunny.topology_registry.x.fanout.13"

    expect(subject.exchanges.size).to be ==(0)
    subject.record_exchange_with(ch, x1_name, :fanout, true, true, {})
    subject.record_exchange_with(ch, x2_name, :fanout, true, true, {})
    subject.record_exchange_with(ch, x3_name, :fanout, true, true, {})
    expect(subject.exchanges.size).to be ==(3)

    expect(subject.exchange_bindings.size).to be ==(0)
    subject.record_exchange_binding_with(ch, x1_name, x2_name, "#", {})
    subject.record_exchange_binding_with(ch, x1_name, x3_name, "#", {})
    expect(subject.exchange_bindings.size).to be ==(2)

    subject.delete_recorded_exchange_named(rand.to_s)
    expect(subject.exchange_bindings.size).to be ==(2)

    subject.delete_recorded_exchange_named(x2_name)
    expect(subject.exchange_bindings.size).to be ==(1)

    subject.delete_recorded_exchange_named(x3_name)
    expect(subject.exchange_bindings.size).to be ==(0)
  end

  it "can update binding destinations when server-named queue name changes" do
    x_name = "bunny.topology_registry.x.fanout.1"
    q1_name = "bunny.topology_registry.cq.10"
    q2_name = "bunny.topology_registry.cq.11"

    subject.record_queue_with(ch, q1_name, false, true, false, false, {})
    subject.record_queue_with(ch, q2_name, false, true, false, false, {})
    expect(subject.queues.size).to be ==(2)

    subject.record_exchange_with(ch, x_name, :fanout, true, true, {})
    expect(subject.exchanges.size).to be ==(1)

    expect(subject.queue_bindings.size).to be ==(0)
    subject.record_queue_binding_with(ch, x_name, q1_name, "#", {})
    subject.record_queue_binding_with(ch, x_name, q2_name, "#", {})
    expect(subject.queue_bindings.size).to be ==(2)

    q1_new_name = "bunny.q1.new_name"
    q2_new_name = "bunny.q2.new_name"
    expect(subject.queues.size).to be ==(2)
    subject.record_queue_name_change(q1_name, q1_new_name)
    subject.record_queue_name_change(q2_name, q2_new_name)
    expect(subject.queues.size).to be ==(2)

    expect(subject.queue_bindings.any? { |rb| rb.destination == q1_name }).to be ==(false)
    expect(subject.queue_bindings.any? { |rb| rb.destination == q1_new_name }).to be ==(true)

    expect(subject.queue_bindings.any? { |rb| rb.destination == q2_name }).to be ==(false)
    expect(subject.queue_bindings.any? { |rb| rb.destination == q2_new_name }).to be ==(true)

    expect(subject.queues.any? { |_, rq| rq.name == q1_name }).to be ==(false)
    expect(subject.queues.any? { |_, rq| rq.name == q1_new_name }).to be ==(true)

    expect(subject.queues.any? { |_, rq| rq.name == q2_name }).to be ==(false)
    expect(subject.queues.any? { |_, rq| rq.name == q2_new_name }).to be ==(true)
  end

  it "retains a non-auto-delete queue when its last consumer is unregistered" do
    q_name = "bunny.topology_registry.cq.nad.1"
    tag = "consumer_tag.nad.001"
    callable = proc { |*args| args }

    subject.record_queue_with(ch, q_name, false, true, false, false, {})
    subject.record_consumer_with(ch, tag, q_name, callable, true, false, {})
    expect(subject.queues.size).to be ==(1)

    subject.delete_recorded_consumer(tag)
    expect(subject.consumers.size).to be ==(0)
    expect(subject.queues.size).to be ==(1)
  end

  it "retains a non-auto-delete exchange when its last binding is removed" do
    x_name = "bunny.topology_registry.x.nad.1"
    q_name = "bunny.topology_registry.cq.nad.2"

    subject.record_exchange_with(ch, x_name, :fanout, true, false, {})
    subject.record_queue_with(ch, q_name, false, true, false, false, {})
    subject.record_exchange_binding_with(ch, x_name, q_name, "#", {})
    expect(subject.exchanges.size).to be ==(1)

    subject.delete_recorded_exchange_binding(ch, x_name, q_name, "#", {})
    expect(subject.exchange_bindings.size).to be ==(0)
    expect(subject.exchanges.size).to be ==(1)
  end

  it "clears all state on reset!" do
    callable = proc { |*args| args }

    subject.record_queue_with(ch, "bunny.reset.q", false, true, false, false, {})
    subject.record_exchange_with(ch, "bunny.reset.x", :fanout, true, false, {})
    subject.record_queue_binding_with(ch, "bunny.reset.x", "bunny.reset.q", "#", {})
    subject.record_exchange_binding_with(ch, "bunny.reset.x", "bunny.reset.x2", "#", {})
    subject.record_consumer_with(ch, "bunny.reset.ctag", "bunny.reset.q", callable, true, false, {})

    subject.reset!

    expect(subject.queues.size).to be ==(0)
    expect(subject.exchanges.size).to be ==(0)
    expect(subject.queue_bindings.size).to be ==(0)
    expect(subject.exchange_bindings.size).to be ==(0)
    expect(subject.consumers.size).to be ==(0)
  end

  describe Bunny::RecordedQueue do
    it "#name_to_use_for_recovery returns empty string for server-named queues" do
      q = Bunny::RecordedQueue.new(ch, "amq.gen-abc123")
        .with_server_named(true)
      expect(q.name_to_use_for_recovery).to eq ""
    end

    it "#name_to_use_for_recovery returns the name for client-named queues" do
      q = Bunny::RecordedQueue.new(ch, "my.queue")
        .with_server_named(false)
      expect(q.name_to_use_for_recovery).to eq "my.queue"
    end
  end

  describe Bunny::RecordedExchange do
    it "#predefined? returns true for amq.* exchanges" do
      ["amq.direct", "amq.fanout", "amq.topic", "amq.headers", "amq.match"].each do |name|
        x = Bunny::RecordedExchange.new(ch, name)
        expect(x).to be_predefined
      end
    end

    it "#predefined? returns true for the default (empty name) exchange" do
      x = Bunny::RecordedExchange.new(ch, "")
      expect(x).to be_predefined
    end

    it "#predefined? returns false for user-declared exchanges" do
      x = Bunny::RecordedExchange.new(ch, "my.exchange")
      expect(x).not_to be_predefined
    end
  end

  describe "filtered methods with default filter" do
    it "returns all entities when no custom filter is set" do
      callable = proc { |*args| args }

      subject.record_queue_with(ch, "bunny.filter.q1", false, true, false, false, {})
      subject.record_exchange_with(ch, "bunny.filter.x1", :fanout, true, false, {})
      subject.record_queue_binding_with(ch, "bunny.filter.x1", "bunny.filter.q1", "#", {})
      subject.record_exchange_binding_with(ch, "bunny.filter.x1", "bunny.filter.x2", "#", {})
      subject.record_consumer_with(ch, "bunny.filter.ctag", "bunny.filter.q1", callable, true, false, {})

      expect(subject.filtered_queues.size).to eq(subject.queues.size)
      expect(subject.filtered_exchanges.size).to eq(subject.exchanges.size)
      expect(subject.filtered_queue_bindings.size).to eq(subject.queue_bindings.size)
      expect(subject.filtered_exchange_bindings.size).to eq(subject.exchange_bindings.size)
      expect(subject.filtered_consumers.size).to eq(subject.consumers.size)

      subject.reset!
    end
  end

  it "can update consumers when server-named queue name changes" do
    x_name = "bunny.topology_registry.x.fanout.1"
    q1_name = "bunny.topology_registry.cq.10"
    q2_name = "bunny.topology_registry.cq.11"

    subject.record_queue_with(ch, q1_name, false, true, false, false, {})
    subject.record_queue_with(ch, q2_name, false, true, false, false, {})
    expect(subject.queues.size).to be ==(2)

    subject.record_exchange_with(ch, x_name, :fanout, true, true, {})
    expect(subject.exchanges.size).to be ==(1)

    expect(subject.queue_bindings.size).to be ==(0)
    subject.record_queue_binding_with(ch, x_name, q1_name, "#", {})
    subject.record_queue_binding_with(ch, x_name, q2_name, "#", {})
    expect(subject.queue_bindings.size).to be ==(2)

    ctag1 = "bunny.ctags.#{rand}.1"
    ctag2 = "bunny.ctags.#{rand}.2"
    callable = proc { |*args| args }

    expect(subject.consumers.size).to be ==(0)
    subject.record_consumer_with(ch, ctag1, q1_name, callable, true, false, {})
    subject.record_consumer_with(ch, ctag2, q2_name, callable, true, false, {})
    expect(subject.consumers.size).to be ==(2)

    q1_new_name = "bunny.q1.new_name"
    q2_new_name = "bunny.q2.new_name"
    subject.record_queue_name_change(q1_name, q1_new_name)
    subject.record_queue_name_change(q2_name, q2_new_name)

    expect(subject.consumers.any? { |_, rc| rc.queue_name == q1_name }).to be ==(false)
    expect(subject.consumers.any? { |_, rc| rc.queue_name == q1_new_name }).to be ==(true)

    expect(subject.consumers.any? { |_, rc| rc.queue_name == q2_name }).to be ==(false)
    expect(subject.consumers.any? { |_, rc| rc.queue_name == q2_new_name }).to be ==(true)

    expect(subject.queues.any? { |_, rq| rq.name == q1_name }).to be ==(false)
    expect(subject.queues.any? { |_, rq| rq.name == q1_new_name }).to be ==(true)

    expect(subject.queues.any? { |_, rq| rq.name == q2_name }).to be ==(false)
    expect(subject.queues.any? { |_, rq| rq.name == q2_new_name }).to be ==(true)
  end
end
