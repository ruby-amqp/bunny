require "spec_helper"

describe Bunny do
  it "has library version" do
    expect(Bunny::VERSION).not_to be_nil
    expect(Bunny.version).not_to be_nil
  end


  it "has AMQP protocol version" do
    expect(Bunny::PROTOCOL_VERSION).to eq "0.9.1"
    expect(AMQ::Protocol::PROTOCOL_VERSION).to eq "0.9.1"
    expect(Bunny.protocol_version).to eq "0.9.1"
  end
end
