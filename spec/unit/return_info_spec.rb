require "spec_helper"
require "bunny/return_info"

describe Bunny::ReturnInfo do
  let(:basic_return) do
    Struct.new(:reply_code, :reply_text, :exchange, :routing_key)
          .new(312, "NO_ROUTE", "my-exchange", "my.routing.key")
  end

  subject { described_class.new(basic_return) }

  describe "accessor methods" do
    it "returns reply_code" do
      expect(subject.reply_code).to eq 312
    end

    it "returns reply_text" do
      expect(subject.reply_text).to eq "NO_ROUTE"
    end

    it "returns exchange" do
      expect(subject.exchange).to eq "my-exchange"
    end

    it "returns routing_key" do
      expect(subject.routing_key).to eq "my.routing.key"
    end
  end

  describe "#[]" do
    it "accesses properties by symbol key" do
      expect(subject[:reply_code]).to eq 312
      expect(subject[:reply_text]).to eq "NO_ROUTE"
      expect(subject[:exchange]).to eq "my-exchange"
      expect(subject[:routing_key]).to eq "my.routing.key"
    end

    it "returns nil for unknown keys" do
      expect(subject[:unknown]).to be_nil
    end
  end

  describe "#to_hash" do
    it "returns a hash with all properties" do
      h = subject.to_hash
      expect(h[:reply_code]).to eq 312
      expect(h[:reply_text]).to eq "NO_ROUTE"
      expect(h[:exchange]).to eq "my-exchange"
      expect(h[:routing_key]).to eq "my.routing.key"
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
      expect(keys).to contain_exactly(:reply_code, :reply_text, :exchange, :routing_key)
    end
  end
end
