require "spec_helper"

describe Bunny::Channel, "#basic_consume" do
  let(:connection) do
    c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed")
    c.start
    c
  end

  after :all do
    connection.close if connection.open?
  end

  it "returns basic.consume-ok when it is received" do
    ch = connection.create_channel
    q  = ch.queue("", :exclusive => true)

    consume_ok = ch.basic_consume(q)
    consume_ok.should be_instance_of(AMQ::Protocol::Basic::ConsumeOk)
    consume_ok.consumer_tag.should_not be_nil

    ch.close
  end

  it "carries server-generated consumer tag with basic.consume-ok" do
    ch = connection.create_channel
    q  = ch.queue("", :exclusive => true)

    consume_ok = ch.basic_consume(q, "")
    consume_ok.consumer_tag.should =~ /amq\.ctag.*/

    ch.close
  end

  context "with automatic acknowledgement mode" do
    let(:queue_name) { "bunny.basic_consume#{rand}" }

    it "causes messages to be automatically removed from the queue after delivery" do
      delivered_keys = []
      delivered_data = []

      t = Thread.new do
        ch = connection.create_channel
        q = ch.queue(queue_name, :auto_delete => true, :durable => false)
        ch.basic_consume(q, "", true, false) do |delivery_info, properties, payload|
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

    it "waits for an explicit acknowledgement" do
      delivered_keys = []
      delivered_data = []

      t = Thread.new do
        ch = connection.create_channel
        q = ch.queue(queue_name, :auto_delete => true, :durable => false)
        ch.basic_consume(q, "", false, false) do |delivery_info, properties, payload|
          delivered_keys << delivery_info.routing_key
          delivered_data << payload

          ch.close
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
end
