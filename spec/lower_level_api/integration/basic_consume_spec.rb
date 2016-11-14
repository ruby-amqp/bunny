require "spec_helper"

describe Bunny::Channel, "#basic_consume" do
  before(:all) do
    @connection = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed")
    @connection.start
  end

  after :all do
    @connection.close if @connection.open?
  end

  it "returns basic.consume-ok when it is received" do
    ch = @connection.create_channel
    q  = ch.queue("", :exclusive => true)

    consume_ok = ch.basic_consume(q)
    expect(consume_ok).to be_instance_of AMQ::Protocol::Basic::ConsumeOk
    expect(consume_ok.consumer_tag).not_to be_nil

    ch.close
  end

  it "carries server-generated consumer tag with basic.consume-ok" do
    ch = @connection.create_channel
    q  = ch.queue("", :exclusive => true)

    consume_ok = ch.basic_consume(q, "")
    expect(consume_ok.consumer_tag).to match /amq\.ctag.*/

    ch.close
  end

  context "with automatic acknowledgement mode" do
    let(:queue_name) { "bunny.basic_consume#{rand}" }

    it "causes messages to be automatically removed from the queue after delivery" do
      delivered_keys = []
      delivered_data = []

      t = Thread.new do
        ch = @connection.create_channel
        q = ch.queue(queue_name, :auto_delete => true, :durable => false)
        ch.basic_consume(q, "", true, false) do |delivery_info, properties, payload|
          delivered_keys << delivery_info.routing_key
          delivered_data << payload
        end
      end
      t.abort_on_exception = true
      sleep 0.5

      ch = @connection.create_channel
      x  = ch.default_exchange
      x.publish("hello", :routing_key => queue_name)

      sleep 0.7
      expect(delivered_keys).to include queue_name
      expect(delivered_data).to include "hello"

      expect(ch.queue(queue_name, :auto_delete => true, :durable => false).message_count).to eq 0

      ch.close
    end
  end

  context "with manual acknowledgement mode" do
    let(:queue_name) { "bunny.basic_consume#{rand}" }

    it "waits for an explicit acknowledgement" do
      delivered_keys = []
      delivered_data = []

      t = Thread.new do
        ch = @connection.create_channel
        q = ch.queue(queue_name, :auto_delete => true, :durable => false)
        ch.basic_consume(q, "", false, false) do |delivery_info, properties, payload|
          delivered_keys << delivery_info.routing_key
          delivered_data << payload

          ch.close
        end
      end
      t.abort_on_exception = true
      sleep 0.5

      ch = @connection.create_channel
      x  = ch.default_exchange
      x.publish("hello", :routing_key => queue_name)

      sleep 0.7
      expect(delivered_keys).to include queue_name
      expect(delivered_data).to include "hello"

      expect(ch.queue(queue_name, :auto_delete => true, :durable => false).message_count).to eq 0

      ch.close
    end
  end
end
