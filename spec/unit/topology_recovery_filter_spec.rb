# -*- coding: utf-8 -*-
# frozen_string_literal: true
require "spec_helper"

describe Bunny::TopologyRegistry do
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

    # These tests use the _with methods which accept primitive values,
    # so no real connection is needed.
    let(:ch) { nil }
    let(:filter) { NameDiscriminatingTopologyFilter.new }

    subject do
      described_class.new(topology_recovery_filter: filter)
    end

    it "can filter queues" do
      q1_name = "bunny.topology_recovery_filtering.cq.1"
      q2_name = "filter-me.bunny.topology_recovery_filtering.cq.2"

      subject.record_queue_with(ch, q1_name, false, true, false, false, {})
      subject.record_queue_with(ch, q2_name, false, true, false, false, {})
      expect(subject.queues.size).to be ==(2)
      expect(subject.filtered_queues.size).to be ==(1)
    end

    it "can filter consumers" do
      q1_name = "bunny.topology_recovery_filtering.cq.3"
      q2_name = "bunny.topology_recovery_filtering.cq.4"
      tag1 = "consumer_tag.32947239847"
      tag2 = "filter-me.consumer_tag.32947239847"
      callable = proc { |*args| args }

      subject.record_consumer_with(ch, tag1, q1_name, callable, true, false, {})
      subject.record_consumer_with(ch, tag2, q2_name, callable, true, false, {})
      expect(subject.consumers.size).to be ==(2)
      expect(subject.filtered_consumers.size).to be ==(1)
    end

    it "can filter exchanges" do
      x1_name = "filter-me.bunny.topology_recovery_filtering.x.fanout.1"
      x2_name = "bunny.topology_recovery_filtering.x.fanout.2"

      subject.record_exchange_with(ch, x1_name, :fanout, true, false, {})
      subject.record_exchange_with(ch, x2_name, :fanout, true, false, {})
      expect(subject.exchanges.size).to be ==(2)
      expect(subject.filtered_exchanges.size).to be ==(1)
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

    it "can filter queue bindings" do
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
