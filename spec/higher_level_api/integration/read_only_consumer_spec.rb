require "spec_helper"

describe Bunny::Queue, "#subscribe" do
  let(:publisher_connection) do
    c = Bunny.new(username: "bunny_gem", password: "bunny_password", vhost: "bunny_testbed")
    c.start
    c
  end

  let(:consumer_connection) do
    c = Bunny.new(username: "bunny_reader", password: "reader_password", vhost: "bunny_testbed")
    c.start
    c
  end

  after :each do
    publisher_connection.close if publisher_connection.open?
    consumer_connection.close  if consumer_connection.open?
  end

  context "with automatic acknowledgement mode" do
    let(:queue_name) { "bunny.basic_consume#{rand}" }

    it "registers the consumer" do
      delivered_keys = []
      delivered_data = []

      ch = publisher_connection.create_channel
      # declare the queue because the read-only user won't be able to issue
      # queue.declare
      q  = ch.queue(queue_name, auto_delete: true, durable: false)

      t = Thread.new do
        # give the main thread a bit of time to declare the queue
        sleep 0.5
        ch = consumer_connection.create_channel
        # this connection is read only, use passive declare to only get
        # a reference to the queue
        q  = ch.queue(queue_name, auto_delete: true, durable: false, passive: true)
        q.subscribe(exclusive: false) do |delivery_info, properties, payload|
          delivered_keys << delivery_info.routing_key
          delivered_data << payload
        end
      end
      t.abort_on_exception = true
      sleep 0.5

      x  = ch.default_exchange
      x.publish("hello", routing_key: queue_name)

      sleep 0.7
      expect(delivered_keys).to include(queue_name)
      expect(delivered_data).to include("hello")

      expect(ch.queue(queue_name, auto_delete: true, durable: false).message_count).to eq 0

      ch.close
    end
  end
end # describe
