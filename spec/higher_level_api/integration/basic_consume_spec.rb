require "spec_helper"
require "set"

describe Bunny::Queue, "#subscribe" do
  let(:connection) do
    c = Bunny.new(username: "bunny_gem", password: "bunny_password", vhost: "bunny_testbed")
    c.start
    c
  end

  after :each do
    connection.close if connection.open?
  end

  context "with automatic acknowledgement mode" do
    let(:queue_name) { "bunny.basic_consume#{rand}" }

    it "registers the consumer" do
      delivered_keys = []
      delivered_data = []

      t = Thread.new do
        ch = connection.create_channel
        q = ch.queue(queue_name, auto_delete: true, durable: false)
        q.subscribe(exclusive: false, manual_ack: false) do |delivery_info, properties, payload|
          delivered_keys << delivery_info.routing_key
          delivered_data << payload
        end
      end
      t.abort_on_exception = true
      sleep 0.5

      ch = connection.create_channel
      x  = ch.default_exchange
      x.publish("hello", routing_key: queue_name)

      sleep 0.7
      expect(delivered_keys).to include(queue_name)
      expect(delivered_data).to include("hello")

      expect(ch.queue(queue_name, auto_delete: true, durable: false).message_count).to eq 0

      ch.close
    end

    context "with a single consumer" do
      let(:queue_name) { "bunny.basic_consume#{rand}" }

      it "provides delivery tag access" do
        delivery_tags = SortedSet.new

        cch = connection.create_channel
        q = cch.queue(queue_name, auto_delete: true, durable: false)
        q.subscribe(exclusive: false, manual_ack: false) do |delivery_info, properties, payload|
          delivery_tags << delivery_info.delivery_tag
        end
        sleep 0.5

        ch = connection.create_channel
        x  = ch.default_exchange
        100.times do
          x.publish("hello", routing_key: queue_name)
        end

        sleep 1.0
        expect(delivery_tags).to eq SortedSet.new(Range.new(1, 100).to_a)

        expect(ch.queue(queue_name, auto_delete: true, durable: false).message_count).to eq 0

        ch.close
      end
    end


    context "with multiple consumers on the same channel" do
      let(:queue_name) { "bunny.basic_consume#{rand}" }

      it "provides delivery tag access" do
        delivery_tags = SortedSet.new

        cch = connection.create_channel
        q   = cch.queue(queue_name, auto_delete: true, durable: false)

        7.times do
          q.subscribe(exclusive: false, manual_ack: false) do |delivery_info, properties, payload|
            delivery_tags << delivery_info.delivery_tag
          end
        end
        sleep 1.0

        ch = connection.create_channel
        x  = ch.default_exchange
        100.times do
          x.publish("hello", routing_key: queue_name)
        end

        sleep 1.5
        expect(delivery_tags).to eq SortedSet.new(Range.new(1, 100).to_a)

        expect(ch.queue(queue_name, auto_delete: true, durable: false).message_count).to eq 0

        ch.close
      end
    end
  end

  context "with manual acknowledgement mode" do
    let(:queue_name) { "bunny.basic_consume#{rand}" }

    it "register a consumer with manual acknowledgements mode" do
      delivered_keys = []
      delivered_data = []

      t = Thread.new do
        ch = connection.create_channel
        q = ch.queue(queue_name, auto_delete: true, durable: false)
        q.subscribe(exclusive: false, manual_ack: true) do |delivery_info, properties, payload|
          delivered_keys << delivery_info.routing_key
          delivered_data << payload

          ch.ack(delivery_info.delivery_tag)
        end
      end
      t.abort_on_exception = true
      sleep 0.5

      ch = connection.create_channel
      x  = ch.default_exchange
      x.publish("hello", routing_key: queue_name)

      sleep 0.7
      expect(delivered_keys).to include(queue_name)
      expect(delivered_data).to include("hello")

      expect(ch.queue(queue_name, auto_delete: true, durable: false).message_count).to eq 0

      ch.close
    end
  end

  ENV.fetch("RUNS", 20).to_i.times do |i|
    context "with a queue that already has messages (take #{i})" do
      let(:queue_name) { "bunny.basic_consume#{rand}" }

      it "registers the consumer" do
        delivered_keys = []
        delivered_data = []

        ch = connection.create_channel
        q  = ch.queue(queue_name, auto_delete: true, durable: false)
        x  = ch.default_exchange
        100.times do
          x.publish("hello", routing_key: queue_name)
        end

        sleep 0.7
        expect(q.message_count).to be > 50

        t = Thread.new do
          ch = connection.create_channel
          q = ch.queue(queue_name, auto_delete: true, durable: false)
          q.subscribe(exclusive: false, manual_ack: false) do |delivery_info, properties, payload|
            delivered_keys << delivery_info.routing_key
            delivered_data << payload
          end
        end
        t.abort_on_exception = true
        sleep 0.5

        expect(delivered_keys).to include(queue_name)
        expect(delivered_data).to include("hello")

        expect(ch.queue(queue_name, auto_delete: true, durable: false).message_count).to eq 0

        ch.close
      end
    end
  end # 20.times


  context "after consumer pool has already been shut down" do
    let(:queue_name) { "bunny.basic_consume#{rand}" }

    it "registers the consumer" do
      delivered_keys = []
      delivered_data = []

      t = Thread.new do
        ch = connection.create_channel
        q  = ch.queue(queue_name)

        c1  = q.subscribe(exclusive: false, manual_ack: false, block: false) do |delivery_info, properties, payload|
        end
        c1.cancel

        c2  = q.subscribe(exclusive: false, manual_ack: false, block: false) do |delivery_info, properties, payload|
          delivered_keys << delivery_info.routing_key
          delivered_data << payload
        end
        c2.cancel

        q.subscribe(exclusive: false, manual_ack: false, block: true) do |delivery_info, properties, payload|
          delivered_keys << delivery_info.routing_key
          delivered_data << payload
        end
      end
      t.abort_on_exception = true
      sleep 0.5

      ch = connection.create_channel
      x  = ch.default_exchange
      x.publish("hello", routing_key: queue_name)

      sleep 0.7
      expect(delivered_keys).to include(queue_name)
      expect(delivered_data).to include("hello")

      expect(ch.queue(queue_name).message_count).to eq 0

      ch.queue_delete(queue_name)
      ch.close
    end
  end


  context "with uncaught exceptions in delivery handler" do
    context "and defined exception handler" do
      let(:queue_name) { "bunny.basic_consume#{rand}" }

      it "uses exception handler" do
        caught = nil
        t = Thread.new do
          ch = connection.create_channel
          q  = ch.queue(queue_name, auto_delete: true, durable: false)

          ch.on_uncaught_exception do |e, consumer|
            caught = e
          end

          q.subscribe(exclusive: false, manual_ack: false) do |delivery_info, properties, payload|
            raise RuntimeError.new(queue_name)
          end
        end
        t.abort_on_exception = true
        sleep 0.5

        ch     = connection.create_channel
        x  = ch.default_exchange
        x.publish("hello", routing_key: queue_name)
        sleep 0.5

        expect(caught.message).to eq queue_name

        ch.close
      end
    end


    context "and default exception handler" do
      let(:queue_name) { "bunny.basic_consume#{rand}" }

      it "uses exception handler" do
        caughts = []
        t = Thread.new do
          allow(connection.logger).to receive(:error) { |x| caughts << x }

          ch = connection.create_channel
          q  = ch.queue(queue_name, auto_delete: true, durable: false)

          q.subscribe(exclusive: false, manual_ack: false) do |delivery_info, properties, payload|
            raise RuntimeError.new(queue_name)
          end
        end
        t.abort_on_exception = true
        sleep 0.5

        ch     = connection.create_channel
        x  = ch.default_exchange
        5.times { x.publish("hello", routing_key: queue_name) }
        sleep 1.5

        expect(caughts.size).to eq(5)

        ch.close
      end
    end


    context "with a single consumer" do
      let(:queue_name) { "bunny.basic_consume#{rand}" }

      it "provides delivery tag access" do
        delivery_tags = SortedSet.new

        cch = connection.create_channel
        q = cch.queue(queue_name, auto_delete: true, durable: false)
        q.subscribe(exclusive: false, manual_ack: false) do |delivery_info, properties, payload|
          delivery_tags << delivery_info.delivery_tag
        end
        sleep 0.5

        ch = connection.create_channel
        x  = ch.default_exchange
        100.times do
          x.publish("hello", routing_key: queue_name)
        end

        sleep 1.0
        expect(delivery_tags).to eq SortedSet.new(Range.new(1, 100).to_a)

        expect(ch.queue(queue_name, auto_delete: true, durable: false).message_count).to eq 0

        ch.close
      end
    end


    context "with multiple consumers on the same channel" do
      let(:queue_name) { "bunny.basic_consume#{rand}" }

      it "provides delivery tag access" do
        delivery_tags = SortedSet.new

        cch = connection.create_channel
        q   = cch.queue(queue_name, auto_delete: true, durable: false)

        7.times do
          q.subscribe(exclusive: false, manual_ack: false) do |delivery_info, properties, payload|
            delivery_tags << delivery_info.delivery_tag
          end
        end
        sleep 1.0

        ch = connection.create_channel
        x  = ch.default_exchange
        100.times do
          x.publish("hello", routing_key: queue_name)
        end

        sleep 1.5
        expect(delivery_tags).to eq SortedSet.new(Range.new(1, 100).to_a)

        expect(ch.queue(queue_name, auto_delete: true, durable: false).message_count).to eq 0

        ch.close
      end
    end
  end
end # describe
