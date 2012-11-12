require "spec_helper"

describe Bunny::Channel, "#ack" do
  let(:connection) do
    c = Bunny.new
    c.start
    c
  end

  subject do
    connection.create_channel
  end

  context "with a valid (known) delivery tag" do
    it "acknowleges a message"
  end

  context "with an invalid (random) delivery tag" do
    it "causes a channel-level error"
  end
end
