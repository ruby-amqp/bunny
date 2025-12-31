require "spec_helper"
require "bunny/message_properties"

describe Bunny::MessageProperties do
  let(:properties) do
    {
      content_type: "application/json",
      content_encoding: "utf-8",
      headers: { "x-custom" => "value" },
      delivery_mode: 2,
      priority: 5,
      correlation_id: "abc123",
      reply_to: "reply.queue",
      expiration: "60000",
      message_id: "msg-001",
      timestamp: Time.at(1234567890),
      type: "order.created",
      user_id: "guest",
      app_id: "my-app",
      cluster_id: "rabbit@localhost"
    }
  end

  subject { described_class.new(properties) }

  describe "accessor methods" do
    it "returns content_type" do
      expect(subject.content_type).to eq "application/json"
    end

    it "returns content_encoding" do
      expect(subject.content_encoding).to eq "utf-8"
    end

    it "returns headers" do
      expect(subject.headers).to eq({ "x-custom" => "value" })
    end

    it "returns delivery_mode" do
      expect(subject.delivery_mode).to eq 2
    end

    it "returns priority" do
      expect(subject.priority).to eq 5
    end

    it "returns correlation_id" do
      expect(subject.correlation_id).to eq "abc123"
    end

    it "returns reply_to" do
      expect(subject.reply_to).to eq "reply.queue"
    end

    it "returns expiration" do
      expect(subject.expiration).to eq "60000"
    end

    it "returns message_id" do
      expect(subject.message_id).to eq "msg-001"
    end

    it "returns timestamp" do
      expect(subject.timestamp).to eq Time.at(1234567890)
    end

    it "returns type" do
      expect(subject.type).to eq "order.created"
    end

    it "returns user_id" do
      expect(subject.user_id).to eq "guest"
    end

    it "returns app_id" do
      expect(subject.app_id).to eq "my-app"
    end

    it "returns cluster_id" do
      expect(subject.cluster_id).to eq "rabbit@localhost"
    end
  end

  describe "#[]" do
    it "accesses properties by symbol key" do
      expect(subject[:content_type]).to eq "application/json"
      expect(subject[:delivery_mode]).to eq 2
    end
  end

  describe "#to_hash" do
    it "returns the properties hash" do
      expect(subject.to_hash).to eq properties
    end
  end

  describe "#each" do
    it "iterates over all properties" do
      keys = []
      subject.each { |k, _| keys << k }
      expect(keys).to include(:content_type, :delivery_mode, :message_id)
    end
  end
end
