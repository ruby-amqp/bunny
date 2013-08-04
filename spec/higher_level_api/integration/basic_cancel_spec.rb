require "spec_helper"

describe Bunny::Consumer, "#cancel" do
  let(:connection) do
    c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed")
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
        q          = ch.queue(queue_name, :auto_delete => true, :durable => false)
        consumer = q.subscribe(:block => false) do |_, _, payload|
          delivered_data << payload
        end

        consumer.consumer_tag.should_not be_nil
        cancel_ok = consumer.cancel
        cancel_ok.consumer_tag.should == consumer.consumer_tag

        ch.close
      end
      t.abort_on_exception = true
      sleep 0.5

      ch = connection.create_channel
      ch.default_exchange.publish("", :routing_key => queue_name)

      sleep 0.7
      delivered_data.should be_empty
    end
  end


  context "with a blocking consumer" do
    let(:queue_name) { "bunny.queues.#{rand}" }

    it "cancels the consumer" do
      delivered_data = []
      consumer       = nil

      t = Thread.new do
        ch         = connection.create_channel
        q          = ch.queue(queue_name, :auto_delete => true, :durable => false)

        consumer   = Bunny::Consumer.new(ch, q)
        consumer.on_delivery do |_, _, payload|
          delivered_data << payload
        end

        q.subscribe_with(consumer, :block => false)
      end
      t.abort_on_exception = true
      sleep 1.0

      consumer.cancel
      sleep 1.0

      ch = connection.create_channel
      ch.default_exchange.publish("", :routing_key => queue_name)

      sleep 0.7
      delivered_data.should be_empty
    end
  end
end
