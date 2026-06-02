# frozen_string_literal: true
require "spec_helper"

describe Bunny::Session do
  describe "#recover_consumer" do
    let(:channel) { instance_double(Bunny::Channel) }

    before { allow(channel).to receive(:maybe_reinitialize_consumer_pool!) }

    def recorded_consumer_with(callable)
      Bunny::RecordedConsumer.new(channel, "bunny.test.queue")
        .with_consumer_tag("bunny-test-tag")
        .with_callable(callable)
        .with_manual_ack(false)
        .with_exclusive(false)
        .with_arguments({})
    end

    it "calls basic_consume_with to preserve Consumer instance identity" do
      consumer = Bunny::Consumer.new(channel, "bunny.test.queue", "bunny-test-tag")
      expect(channel).to receive(:basic_consume_with).with(consumer)
      Bunny.new.recover_consumer(recorded_consumer_with(consumer))
    end

    it "calls basic_consume with a block when callable is a Proc" do
      callable = proc { |*args| args }
      expect(channel).to receive(:basic_consume).with("bunny.test.queue", "bunny-test-tag", true, false, {})
      Bunny.new.recover_consumer(recorded_consumer_with(callable))
    end
  end
end
