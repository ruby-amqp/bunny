require "spec_helper"

describe Bunny::Channel do
  let(:connection) do
    c = Bunny.new
    c.start
    c
  end

  subject do
    connection.create_channel
  end

  context "with a positive integer" do
    it "sets that prefetch level via basic.qos" do
      subject.prefetch(10).should be_instance_of(AMQ::Protocol::Basic::QosOk)
    end
  end

  context "with a negative integer" do
    it "raises an ArgumentError" do
      expect {
        subject.prefetch(-2)
      }.to raise_error(ArgumentError)
    end
  end
end
