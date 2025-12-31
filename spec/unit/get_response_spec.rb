require "spec_helper"
require "bunny/get_response"

describe Bunny::GetResponse do
  let(:get_ok) do
    Struct.new(:delivery_tag, :redelivered, :exchange, :routing_key)
          .new(456, false, "my-exchange", "my.routing.key")
  end
  let(:channel) { double("channel") }

  subject { described_class.new(get_ok, channel) }

  describe "accessor methods" do
    it "returns delivery_tag" do
      expect(subject.delivery_tag).to eq 456
    end

    it "returns redelivered" do
      expect(subject.redelivered).to eq false
      expect(subject.redelivered?).to eq false
    end

    it "returns exchange" do
      expect(subject.exchange).to eq "my-exchange"
    end

    it "returns routing_key" do
      expect(subject.routing_key).to eq "my.routing.key"
    end

    it "returns channel" do
      expect(subject.channel).to eq channel
    end
  end

  describe "#[]" do
    it "accesses properties by symbol key" do
      expect(subject[:delivery_tag]).to eq 456
      expect(subject[:redelivered]).to eq false
      expect(subject[:exchange]).to eq "my-exchange"
      expect(subject[:routing_key]).to eq "my.routing.key"
      expect(subject[:channel]).to eq channel
    end

    it "returns nil for unknown keys" do
      expect(subject[:unknown]).to be_nil
    end
  end

  describe "#to_hash" do
    it "returns a hash with all properties" do
      h = subject.to_hash
      expect(h[:delivery_tag]).to eq 456
      expect(h[:redelivered]).to eq false
      expect(h[:exchange]).to eq "my-exchange"
      expect(h[:routing_key]).to eq "my.routing.key"
      expect(h[:channel]).to eq channel
    end

    it "memoizes the hash" do
      h1 = subject.to_hash
      h2 = subject.to_hash
      expect(h1).to equal(h2)
    end
  end

  describe "#each" do
    it "iterates over all properties" do
      keys = []
      subject.each { |k, _| keys << k }
      expect(keys).to contain_exactly(:delivery_tag, :redelivered, :exchange, :routing_key, :channel)
    end
  end
end
