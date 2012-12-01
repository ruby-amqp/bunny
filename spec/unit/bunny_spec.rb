require "spec_helper"

describe Bunny do
  it "has library version" do
    Bunny::VERSION.should_not be_nil
    Bunny.version.should_not be_nil
  end


  it "has AMQP protocol version" do
    Bunny::PROTOCOL_VERSION.should == "0.9.1"
    AMQ::Protocol::PROTOCOL_VERSION.should == "0.9.1"
    Bunny.protocol_version.should == "0.9.1"
  end
end
