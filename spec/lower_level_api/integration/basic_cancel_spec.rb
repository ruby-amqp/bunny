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
    it "cancels the consumer"
  end

  context "when the given consumer tag is invalid (was never registered)" do
    it "causes a channel error"
  end
end
