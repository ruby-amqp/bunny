require "spec_helper"

describe Bunny::Channel do
  let(:connection) do
    c = Bunny.new(username: "bunny_gem", password: "bunny_password", vhost: "bunny_testbed")
    c.start
    c
  end

  after :each do
    connection.close if connection.open?
  end

  context "with implicit consumer construction" do
    let(:queue_name) { "basic.consume#{rand}" }

    it "supports consumer cancellation notifications" do
      cancelled = false

      ch = connection.create_channel
      t  = Thread.new do
        ch2 = connection.create_channel
        q   = ch2.durable_queue(queue_name, Bunny::Queue::Types::QUORUM, arguments: {"x-expires": 20000})

        q.subscribe(on_cancellation: Proc.new { cancelled = true })
      end
      t.abort_on_exception = true

      sleep 0.5
      x = ch.default_exchange
      x.publish("abc", routing_key: queue_name)

      sleep 0.5
      ch.durable_queue(queue_name, Bunny::Queue::Types::QUORUM, arguments: {"x-expires": 20000}).delete

      sleep 0.5
      expect(cancelled).to eq true

      ch.close
    end
  end


  context "with explicit consumer construction" do
    class ExampleConsumer < Bunny::Consumer
      def cancelled?
        @cancelled
      end

      def handle_cancellation(_)
        @cancelled = true
      end
    end

    let(:queue_name) { "basic.consume#{rand}" }

    it "supports consumer cancellation notifications" do
      consumer = nil

      ch = connection.create_channel
      t  = Thread.new do
        ch2 = connection.create_channel
        q   = ch2.durable_queue(queue_name, Bunny::Queue::Types::QUORUM, arguments: {"x-expires": 20000})

        consumer = ExampleConsumer.new(ch2, q, "")
        q.subscribe_with(consumer)
      end
      t.abort_on_exception = true

      sleep 0.5
      x = ch.default_exchange
      x.publish("abc", routing_key: queue_name)

      sleep 0.5
      ch.durable_queue(queue_name, Bunny::Queue::Types::QUORUM, arguments: {"x-expires": 20000}).delete

      sleep 0.5
      expect(consumer).to be_cancelled

      ch.close
    end
  end



  context "with consumer re-registration" do
    class ExampleConsumerThatReregisters < Bunny::Consumer
      def handle_cancellation(_)
        @queue = @channel.durable_queue("basic.consume.after_cancellation", Bunny::Queue::Types::QUORUM, arguments: {"x-expires": 20000})
        @channel.basic_consume_with(self)
      end
    end

    let(:queue_name) { "basic.consume#{rand}" }

    it "works correctly" do
      consumer = nil
      xs       = []

      ch = connection.create_channel
      t  = Thread.new do
        ch2 = connection.create_channel
        q   = ch2.durable_queue(queue_name, Bunny::Queue::Types::QUORUM, arguments: {"x-expires": 20000})

        consumer = ExampleConsumerThatReregisters.new(ch2, q, "")
        consumer.on_delivery do |_, _, payload|
          xs << payload
        end
        q.subscribe_with(consumer)
      end
      t.abort_on_exception = true

      sleep 0.5
      x = ch.default_exchange
      x.publish("abc", routing_key: queue_name)

      sleep 0.5
      ch.durable_queue("basic.consume.after_cancellation", Bunny::Queue::Types::QUORUM, arguments: {"x-expires": 20000}).delete

      q = ch.durable_queue("basic.consume.after_cancellation", Bunny::Queue::Types::QUORUM, arguments: {"x-expires": 20000})
      expect(xs).to eq ["abc"]

      ch.durable_queue("basic.consume.after_cancellation", Bunny::Queue::Types::QUORUM, arguments: {"x-expires": 20000}).delete

      ch.close
    end
  end
end
