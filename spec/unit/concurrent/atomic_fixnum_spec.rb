require "spec_helper"
require "bunny/concurrent/atomic_fixnum"

describe Bunny::Concurrent::AtomicFixnum do
  it "allows retrieving the current value" do
    af = described_class.new(0)

    expect(af.get).to eq 0
    expect(af).to eq 0
  end

  it "can be updated" do
    af = described_class.new(0)

    expect(af.get).to eq 0
    Thread.new do
      af.set(10)
    end
    sleep 0.6
    expect(af.get).to eq 10
  end

  it "can be incremented" do
    af = described_class.new(0)

    expect(af.get).to eq 0
    10.times do
      Thread.new do
        af.increment
      end
    end
    sleep 0.6
    expect(af.get).to eq 10
  end
end
