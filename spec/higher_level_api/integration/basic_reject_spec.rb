require "spec_helper"

describe Bunny::Channel, "#reject" do
  let(:connection) do
    c = Bunny.new
    c.start
    c
  end

  subject do
    connection.create_channel
  end

  context "with requeue = true" do
    it "requeues a message"
  end

  context "with requeue = false" do
    it "rejects a message"
  end
end
