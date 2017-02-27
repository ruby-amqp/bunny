require "spec_helper"

describe Bunny::Consumer, "#cancel" do
  let(:connection) do
    c = Bunny.new(username: "bunny_gem", password: "bunny_password", vhost: "bunny_testbed")
    c.start
    c
  end

  after :each do
    connection.close if connection.open?
  end

  context "with a non-blocking consumer" do
    let(:queue_name) { "bunny.queues.#{rand}" }

    it "cancels the consumer" do
      delivered_data = []

      t = Thread.new do
        ch         = connection.create_channel
        q          = ch.queue(queue_name, auto_delete: true, durable: false)
        consumer = q.subscribe(block: false) do |_, _, payload|
          delivered_data << payload
        end

        expect(consumer.consumer_tag).not_to be_nil
        cancel_ok = consumer.cancel
        expect(cancel_ok.consumer_tag).to eq consumer.consumer_tag

        ch.close
      end
      t.abort_on_exception = true
      sleep 0.5

      ch = connection.create_channel
      ch.default_exchange.publish("", routing_key: queue_name)

      sleep 0.7
      expect(delivered_data).to be_empty
    end
  end


  context "with a blocking consumer" do
    let(:queue_name) { "bunny.queues.#{rand}" }

    it "cancels the consumer" do
      delivered_data = []
      consumer       = nil

      t = Thread.new do
        ch         = connection.create_channel
        q          = ch.queue(queue_name, auto_delete: true, durable: false)

        consumer   = Bunny::Consumer.new(ch, q)
        consumer.on_delivery do |_, _, payload|
          delivered_data << payload
        end

        q.subscribe_with(consumer, block: false)
      end
      t.abort_on_exception = true
      sleep 1.0

      consumer.cancel
      sleep 1.0

      ch = connection.create_channel
      ch.default_exchange.publish("", routing_key: queue_name)

      sleep 0.7
      expect(delivered_data).to be_empty
    end
  end

  context "with a worker pool shutdown timeout configured" do
    let(:queue_name) { "bunny.queues.#{rand}" }

    it "processes the message if processing completes within the timeout" do
      delivered_data = []
      consumer       = nil

      t = Thread.new do
        ch         = connection.create_channel(nil, 1, false, 5)
        q          = ch.queue(queue_name, auto_delete: true, durable: false)

        consumer   = Bunny::Consumer.new(ch, q)
        consumer.on_delivery do |_, _, payload|
          sleep 2
          delivered_data << payload
        end

        q.subscribe_with(consumer, block: false)
      end
      t.abort_on_exception = true
      sleep 1.0

      ch = connection.create_channel
      ch.confirm_select
      ch.default_exchange.publish("", routing_key: queue_name)
      ch.wait_for_confirms
      sleep 0.5

      consumer.cancel
      sleep 1.0

      expect(delivered_data).to_not be_empty
    end

    it "kills the consumer if processing takes longer than the timeout" do
      delivered_data = []
      consumer       = nil

      t = Thread.new do
        ch         = connection.create_channel(nil, 1, false, 1)
        q          = ch.queue(queue_name, auto_delete: true, durable: false)

        consumer   = Bunny::Consumer.new(ch, q)
        consumer.on_delivery do |_, _, payload|
          sleep 3
          delivered_data << payload
        end

        q.subscribe_with(consumer, block: false)
      end
      t.abort_on_exception = true
      sleep 1.0

      ch = connection.create_channel
      ch.confirm_select
      ch.default_exchange.publish("", routing_key: queue_name)
      ch.wait_for_confirms
      sleep 0.5

      consumer.cancel
      sleep 1.0

      expect(delivered_data).to be_empty
    end
  end
end
