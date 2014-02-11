require "spec_helper"

describe Bunny::Channel, "#basic_cancel" do
  let(:connection) do
    c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed")
    c.start
    c
  end

  after :all do
    connection.close if connection.open?
  end

  let(:queue_name) { "bunny.queues.#{rand}" }

  it "returns basic.cancel-ok" do
    ch = connection.create_channel
    q  = ch.queue("", :exclusive => true)

    consume_ok = ch.basic_consume(q, "")
    cancel_ok  = ch.basic_cancel(consume_ok.consumer_tag)

    cancel_ok.should be_instance_of(AMQ::Protocol::Basic::CancelOk)
    cancel_ok.consumer_tag.should == consume_ok.consumer_tag

    ch.close
  end

  context "when the given consumer tag is valid" do
    let(:queue_name) { "bunny.basic.cancel.queue#{rand}" }

    it "cancels the consumer" do
      delivered_data = []

      t = Thread.new do
        ch         = connection.create_channel
        q          = ch.queue(queue_name, :auto_delete => true, :durable => false)
        consume_ok = ch.basic_consume(q, "", true, false) do |_, _, payload|
          delivered_data << payload
        end

        consume_ok.consumer_tag.should_not be_nil
        cancel_ok = ch.basic_cancel(consume_ok.consumer_tag)
        cancel_ok.consumer_tag.should == consume_ok.consumer_tag

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

  context "when the given consumer tag is invalid (was never registered)" do
    it "DOES NOT cause a channel error" do
      ch = connection.create_channel

      # RabbitMQ 3.1 does not raise an exception w/ unknown consumer tag. MK.
      ch.basic_cancel("878798s7df89#{rand}#{Time.now.to_i}")

      ch.close
    end
  end

  context "when the given consumer tag belongs to a different channel" do
    it "DOES NOT cause a channel error" do
      ch1 = connection.create_channel
      ch2 = connection.create_channel

      q    = ch1.queue("", :exclusive => true)
      cons = q.subscribe do |_, _, _|
      end
      ch2.basic_cancel(cons.consumer_tag)

      ch1.close
      ch2.close
    end
  end
end
