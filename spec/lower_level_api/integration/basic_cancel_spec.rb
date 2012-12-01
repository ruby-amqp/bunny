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
        consume_ok = ch.basic_consume(q, "", true, false) do |metadata, payload|
          delivered_data << payload
        end

        consume_ok.consumer_tag.should_not be_nil
        cancel_ok = ch.basic_cancel(consume_ok.consumer_tag)
        cancel_ok.consumer_tag.should == consume_ok.consumer_tag

        ch.close
      end
      t.abort_on_exception = true
      sleep 0.5

      sleep 0.7
      delivered_data.should be_empty
    end
  end

  context "when the given consumer tag is invalid (was never registered)" do
    it "causes a channel error"
  end
end
