require "spec_helper"

describe Bunny::Channel, "#flow" do
  let(:connection) do
    c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed")
    c.start
    c
  end

  after :each do
    connection.close
  end

  it "is supported" do
    ch = connection.create_channel

    ch.flow(true).should be_instance_of(AMQ::Protocol::Channel::FlowOk)
    ch.flow(false).should be_instance_of(AMQ::Protocol::Channel::FlowOk)
    ch.flow(true).should be_instance_of(AMQ::Protocol::Channel::FlowOk)
  end
end
