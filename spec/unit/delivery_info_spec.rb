require "spec_helper"
require "bunny/delivery_info"

describe Bunny::DeliveryInfo do
  let(:basic_deliver) do
    Struct.new(:consumer_tag, :delivery_tag, :redelivered, :exchange, :routing_key)
          .new("ctag", 123, false, "my-exchange", "my.routing.key")
  end
  let(:consumer) { double("consumer") }
  let(:channel)  { double("channel") }

  subject { described_class.new(basic_deliver, consumer, channel) }

  describe "accessor methods" do
    it "returns consumer_tag" do
      expect(subject.consumer_tag).to eq "ctag"
    end

    it "returns delivery_tag" do
      expect(subject.delivery_tag).to eq 123
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

    it "returns consumer" do
      expect(subject.consumer).to eq consumer
    end

    it "returns channel" do
      expect(subject.channel).to eq channel
    end
  end

  describe "#[]" do
    it "accesses properties by symbol key" do
      expect(subject[:consumer_tag]).to eq "ctag"
      expect(subject[:delivery_tag]).to eq 123
      expect(subject[:redelivered]).to eq false
      expect(subject[:exchange]).to eq "my-exchange"
      expect(subject[:routing_key]).to eq "my.routing.key"
      expect(subject[:consumer]).to eq consumer
      expect(subject[:channel]).to eq channel
    end

    it "returns nil for unknown keys" do
      expect(subject[:unknown]).to be_nil
    end
  end

  describe "#to_hash" do
    it "returns a hash with all properties" do
      h = subject.to_hash
      expect(h[:consumer_tag]).to eq "ctag"
      expect(h[:delivery_tag]).to eq 123
      expect(h[:redelivered]).to eq false
      expect(h[:exchange]).to eq "my-exchange"
      expect(h[:routing_key]).to eq "my.routing.key"
      expect(h[:consumer]).to eq consumer
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
      expect(keys).to contain_exactly(:consumer_tag, :delivery_tag, :redelivered, :exchange, :routing_key, :consumer, :channel)
    end
  end

  describe "#to_s" do
    it "returns string representation" do
      expect(subject.to_s).to be_a(String)
      expect(subject.to_s).to include("ctag")
    end
  end

  describe "#inspect" do
    it "returns inspectable string" do
      expect(subject.inspect).to be_a(String)
      expect(subject.inspect).to include("ctag")
    end
  end
end
