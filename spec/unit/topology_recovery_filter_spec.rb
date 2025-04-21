# -*- coding: utf-8 -*-
# frozen_string_literal: true
require "spec_helper"

describe Bunny::TopologyRegistry do
  class ExampleConsumer < Bunny::Consumer
    def call(delivery_info, metadata, payload)
       # no-op
    end
  end

  describe "filter" do
    class NameDiscriminatingTopologyFilter < Bunny::TopologyRecoveryFilter
      def filter_queues(qs)
        qs.filter { |rq| rq.name.start_with?(/^filter-me/) }
      end

      def filter_exchanges(xs)
        xs.filter { |rx| rx.name.start_with?(/^filter-me/) }
      end

      def filter_queue_bindings(bs)
        bs.filter { |rb| rb.destination.start_with?(/^filter-me/) }
      end

      def filter_exchange_bindings(bs)
        bs.filter { |rb| rb.destination.start_with?(/^filter-me/) }
      end

      def filter_consumers(bs)
        bs.filter { |rc| rc.consumer_tag.start_with?(/filter-me/) }
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

    let(:filter) { NameDiscriminatingTopologyFilter.new }

    subject do
      described_class.new(topology_recovery_filter: filter)
    end

    it "can filter queues" do
      q1 = ch.durable_queue("bunny.topology_recovery_filtering.cq.1")
      q2 = ch.durable_queue("filter-me.bunny.topology_recovery_filtering.cq.2")

      subject.record_queue(q1)
      subject.record_queue(q2)
      expect(subject.queues.size).to be ==(2)
      expect(subject.filtered_queues.size).to be ==(1)

      q1.delete
      q2.delete
    end

    it "can filter consumers" do
      q1 = ch.durable_queue("bunny.topology_recovery_filtering.cq.3")
      q2 = ch.durable_queue("bunny.topology_recovery_filtering.cq.4")
      cons1 = ExampleConsumer.new(ch, q1)
      tag1 = "consumer_tag.32947239847"
      cons2 = ExampleConsumer.new(ch, q2)
      tag2 = "filter-me.consumer_tag.32947239847"

      subject.record_consumer_with(ch, tag1, q1.name, cons1, true, false, {})
      subject.record_consumer_with(ch, tag2, q2.name, cons2, true, false, {})
      expect(subject.consumers.size).to be ==(2)
      expect(subject.filtered_consumers.size).to be ==(1)

      q1.delete
      q2.delete
    end

    it "can filter exchanges" do
      x1_name = "filter-me.bunny.topology_recovery_filtering.x.fanout.1"
      x2_name = "bunny.topology_recovery_filtering.x.fanout.2"
      ch.exchange_delete(x1_name)
      ch.exchange_delete(x2_name)
      x1 = ch.fanout(x1_name, durable: true)
      x2 = ch.fanout(x2_name, durable: true)

      subject.record_exchange(x1)
      subject.record_exchange(x2)
      expect(subject.exchanges.size).to be ==(2)
      expect(subject.filtered_exchanges.size).to be ==(1)

      x1.delete
      x2.delete
    end

    it "can filter exchange bindings" do
      source_name1 = "bunny.topology_recovery_filtering.x.fanout.1"
      dest_name1 = "bunny.topology_recovery_filtering.x.topic.1"
      source_name2 = "filter-me.bunny.topology_recovery_filtering.x.fanout.2"
      dest_name2 = "filter-me.bunny.topology_recovery_filtering.x.topic.2"

      subject.record_exchange_binding_with(ch, source_name1, dest_name1, "#", {})
      subject.record_exchange_binding_with(ch, source_name2, dest_name2, "#", {})
      expect(subject.exchange_bindings.size).to be ==(2)
      expect(subject.filtered_exchange_bindings.size).to be ==(1)

      subject.reset!
    end

    it "cna filter queue bindings" do
      x1_name = "bunny.topology_recovery_filtering.x.fanout.1"
      q1_name = "bunny.topology_recovery_filtering.qq.4"
      x2_name = "filter-me.bunny.topology_recovery_filtering.x.fanout.2"
      q2_name = "filter-me.bunny.topology_recovery_filtering.qq.5"

      subject.record_queue_binding_with(ch, x1_name, q1_name, "#", {})
      subject.record_queue_binding_with(ch, x2_name, q2_name, "#", {})
      expect(subject.queue_bindings.size).to be ==(2)
      expect(subject.filtered_queue_bindings.size).to be ==(1)

      subject.reset!
    end
  end
end
