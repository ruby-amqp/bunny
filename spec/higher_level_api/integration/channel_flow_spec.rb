require "spec_helper"

describe Bunny::Channel, "#flow" do
  let(:connection) do
    c = Bunny.new
    c.start
    c
  end

  after :all do
    connection.close
  end


  subject do
    connection.create_channel
  end

  it "is supported" do
    subject.flow(true).should be_instance_of(AMQ::Protocol::Channel::FlowOk)
    subject.flow(false).should be_instance_of(AMQ::Protocol::Channel::FlowOk)
    subject.flow(true).should be_instance_of(AMQ::Protocol::Channel::FlowOk)
  end
end
