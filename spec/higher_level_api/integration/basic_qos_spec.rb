require "spec_helper"

describe Bunny::Channel, "#prefetch" do
  let(:connection) do
    c = Bunny.new(username: "bunny_gem", password: "bunny_password", vhost: "bunny_testbed")
    c.start
    c
  end

  after :each do
    connection.close
  end

  context "with a positive integer < 65535" do
    it "sets that prefetch level via basic.qos" do
      ch = connection.create_channel
      expect(ch.prefetch_count).not_to eq 10
      expect(ch.prefetch_global).to be_nil
      expect(ch.prefetch(10)).to be_instance_of(AMQ::Protocol::Basic::QosOk)
      expect(ch.prefetch_count).to eq 10
      expect(ch.prefetch_global).to be false
    end

    it "sets that prefetch global via basic.qos" do
      ch = connection.create_channel
      expect(ch.prefetch_count).not_to eq 42
      expect(ch.prefetch_global).to be_nil
      expect(ch.prefetch(42, true)).to be_instance_of(AMQ::Protocol::Basic::QosOk)
      expect(ch.prefetch_count).to eq 42
      expect(ch.prefetch_global).to be true
    end
  end

  context "with a positive integer > 65535" do
    it "raises an ArgumentError" do
      ch = connection.create_channel
      expect {
        ch.prefetch(100_000)
      }.to raise_error(
        ArgumentError,
        "prefetch count must be no greater than #{Bunny::Channel::MAX_PREFETCH_COUNT}, given: 100000"
      )
    end
  end

  context "with a negative integer" do
    it "raises an ArgumentError" do
      ch = connection.create_channel
      expect {
        ch.prefetch(-2)
      }.to raise_error(
        ArgumentError,
        "prefetch count must be a positive integer, given: -2"
      )
    end
  end
end
