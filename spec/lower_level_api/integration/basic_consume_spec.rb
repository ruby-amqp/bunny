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
  end

  context "with manual acknowledgement mode" do
  end
end
