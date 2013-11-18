require "spec_helper"

require "bunny/concurrent/atomic_fixnum"
require "bunny/versioned_delivery_tag"

describe Bunny::VersionedDeliveryTag, "#stale?" do
  subject { described_class.new(2, 1) }

  context "when delivery tag version < provided version" do
    it "returns true" do
      subject.stale?(2).should be_true
    end
  end

  context "when delivery tag version = provided version" do
    it "returns false" do
      subject.stale?(1).should be_false
    end
  end

  context "when delivery tag version > provided version" do
    it "returns true" do
      # this scenario is unrealistic but we still can
      # unit test it. MK.
      subject.stale?(0).should be_false
    end
  end
end
