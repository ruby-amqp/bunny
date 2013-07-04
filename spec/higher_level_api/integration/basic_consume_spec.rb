require "spec_helper"

describe Bunny::Queue, "#subscribe" do
  let(:connection) do
    c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed")
    c.start
    c
  end

  after :all do
    connection.close if connection.open?
  end

  context "with automatic acknowledgement mode" do
    let(:queue_name) { "bunny.basic_consume#{rand}" }

    it "registers the consumer" do
      delivered_keys = []
      delivered_data = []

      t = Thread.new do
        ch = connection.create_channel
        q = ch.queue(queue_name, :auto_delete => true, :durable => false)
        q.subscribe(:exclusive => false, :manual_ack => false) do |delivery_info, properties, payload|
          delivered_keys << delivery_info.routing_key
          delivered_data << payload
        end
      end
      t.abort_on_exception = true
      sleep 0.5

      ch = connection.create_channel
      x  = ch.default_exchange
      x.publish("hello", :routing_key => queue_name)

      sleep 0.7
      delivered_keys.should include(queue_name)
      delivered_data.should include("hello")

      ch.queue(queue_name, :auto_delete => true, :durable => false).message_count.should == 0

      ch.close
    end
  end

  context "with manual acknowledgement mode" do
    let(:queue_name) { "bunny.basic_consume#{rand}" }

    it "register a consumer with manual acknowledgements mode" do
      delivered_keys = []
      delivered_data = []

      t = Thread.new do
        ch = connection.create_channel
        q = ch.queue(queue_name, :auto_delete => true, :durable => false)
        q.subscribe(:exclusive => false, :manual_ack => true) do |delivery_info, properties, payload|
          delivered_keys << delivery_info.routing_key
          delivered_data << payload

          ch.ack(delivery_info.delivery_tag)
        end
      end
      t.abort_on_exception = true
      sleep 0.5

      ch = connection.create_channel
      x  = ch.default_exchange
      x.publish("hello", :routing_key => queue_name)

      sleep 0.7
      delivered_keys.should include(queue_name)
      delivered_data.should include("hello")

      ch.queue(queue_name, :auto_delete => true, :durable => false).message_count.should == 0

      ch.close
    end
  end

  20.times do |i|
    context "with a queue that already has messages (take #{i})" do
      let(:queue_name) { "bunny.basic_consume#{rand}" }

      it "registers the consumer" do
        delivered_keys = []
        delivered_data = []

        ch = connection.create_channel
        q  = ch.queue(queue_name, :auto_delete => true, :durable => false)
        x  = ch.default_exchange
        100.times do
          x.publish("hello", :routing_key => queue_name)
        end

        sleep 0.7
        q.message_count.should be > 50

        t = Thread.new do
          ch = connection.create_channel
          q = ch.queue(queue_name, :auto_delete => true, :durable => false)
          q.subscribe(:exclusive => false, :manual_ack => false) do |delivery_info, properties, payload|
            delivered_keys << delivery_info.routing_key
            delivered_data << payload
          end
        end
        t.abort_on_exception = true
        sleep 0.5

        delivered_keys.should include(queue_name)
        delivered_data.should include("hello")

        ch.queue(queue_name, :auto_delete => true, :durable => false).message_count.should == 0

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

        c1  = q.subscribe(:exclusive => false, :manual_ack => false, :block => false) do |delivery_info, properties, payload|
        end
        c1.cancel

        c2  = q.subscribe(:exclusive => false, :manual_ack => false, :block => false) do |delivery_info, properties, payload|
          delivered_keys << delivery_info.routing_key
          delivered_data << payload
        end
        c2.cancel

        q.subscribe(:exclusive => false, :manual_ack => false, :block => true) do |delivery_info, properties, payload|
          delivered_keys << delivery_info.routing_key
          delivered_data << payload
        end
      end
      t.abort_on_exception = true
      sleep 0.5

      ch = connection.create_channel
      x  = ch.default_exchange
      x.publish("hello", :routing_key => queue_name)

      sleep 0.7
      delivered_keys.should include(queue_name)
      delivered_data.should include("hello")

      ch.queue(queue_name).message_count.should == 0

      ch.queue_delete(queue_name)
      ch.close
    end
  end

end # describe
