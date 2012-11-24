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
        q.subscribe(:exclusive => false, :ack => false) do |metadata, payload|
          delivered_keys << metadata.routing_key
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

    it "register a consumer with manual acknowledgements mode"
  end
end
