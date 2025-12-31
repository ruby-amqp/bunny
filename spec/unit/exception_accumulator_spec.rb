# frozen_string_literal: true

require "spec_helper"

describe Bunny::Concurrent::ExceptionAccumulator do
  subject { described_class.new }

  describe "#raise" do
    it "accumulates exceptions instead of raising them" do
      exception = RuntimeError.new("test error")
      expect { subject.raise(exception) }.not_to raise_error
      expect(subject.any?).to be true
    end

    it "is thread-safe" do
      threads = 10.times.map do |i|
        Thread.new do
          subject.raise(RuntimeError.new("error #{i}"))
        end
      end
      threads.each(&:join)

      expect(subject.count).to eq 10
    end
  end

  describe "#any?" do
    it "returns false when no exceptions are accumulated" do
      expect(subject.any?).to be false
    end

    it "returns true when exceptions are accumulated" do
      subject.raise(RuntimeError.new("test"))
      expect(subject.any?).to be true
    end
  end

  describe "#empty?" do
    it "returns true when no exceptions are accumulated" do
      expect(subject.empty?).to be true
    end

    it "returns false when exceptions are accumulated" do
      subject.raise(RuntimeError.new("test"))
      expect(subject.empty?).to be false
    end
  end

  describe "#count" do
    it "returns 0 when no exceptions are accumulated" do
      expect(subject.count).to eq 0
    end

    it "returns the correct count of accumulated exceptions" do
      subject.raise(RuntimeError.new("error 1"))
      subject.raise(RuntimeError.new("error 2"))
      subject.raise(RuntimeError.new("error 3"))
      expect(subject.count).to eq 3
    end
  end

  describe "#all" do
    it "returns an empty array when no exceptions are accumulated" do
      expect(subject.all).to eq []
    end

    it "returns all accumulated exceptions" do
      e1 = RuntimeError.new("error 1")
      e2 = RuntimeError.new("error 2")
      subject.raise(e1)
      subject.raise(e2)

      exceptions = subject.all
      expect(exceptions).to eq [e1, e2]
    end

    it "returns a copy of the exceptions array" do
      e1 = RuntimeError.new("error 1")
      subject.raise(e1)

      exceptions = subject.all
      exceptions.clear

      expect(subject.count).to eq 1
    end
  end

  describe "#pop" do
    it "returns nil when no exceptions are accumulated" do
      expect(subject.pop).to be_nil
    end

    it "returns and removes the first exception (FIFO order)" do
      e1 = RuntimeError.new("error 1")
      e2 = RuntimeError.new("error 2")
      subject.raise(e1)
      subject.raise(e2)

      expect(subject.pop).to eq e1
      expect(subject.count).to eq 1
      expect(subject.pop).to eq e2
      expect(subject.count).to eq 0
    end
  end

  describe "#clear" do
    it "returns empty array when no exceptions are accumulated" do
      expect(subject.clear).to eq []
    end

    it "returns and removes all accumulated exceptions" do
      e1 = RuntimeError.new("error 1")
      e2 = RuntimeError.new("error 2")
      subject.raise(e1)
      subject.raise(e2)

      cleared = subject.clear
      expect(cleared).to eq [e1, e2]
      expect(subject.empty?).to be true
    end
  end

  describe "#raise_first!" do
    it "does nothing when no exceptions are accumulated" do
      expect { subject.raise_first! }.not_to raise_error
    end

    it "raises the first accumulated exception" do
      e1 = RuntimeError.new("error 1")
      e2 = RuntimeError.new("error 2")
      subject.raise(e1)
      subject.raise(e2)

      expect { subject.raise_first! }.to raise_error(RuntimeError, "error 1")
      expect(subject.count).to eq 1
    end
  end

  describe "#raise_all!" do
    it "does nothing when no exceptions are accumulated" do
      expect { subject.raise_all! }.not_to raise_error
    end

    it "raises AccumulatedExceptions containing all accumulated exceptions" do
      e1 = RuntimeError.new("error 1")
      e2 = ArgumentError.new("error 2")
      subject.raise(e1)
      subject.raise(e2)

      expect { subject.raise_all! }.to raise_error(Bunny::AccumulatedExceptions) do |error|
        expect(error.exceptions).to eq [e1, e2]
        expect(error.message).to include("2 exception(s) accumulated")
        expect(error.message).to include("RuntimeError: error 1")
        expect(error.message).to include("ArgumentError: error 2")
      end
      expect(subject.empty?).to be true
    end
  end
end

describe Bunny::AccumulatedExceptions do
  describe "#initialize" do
    it "stores the exceptions" do
      e1 = RuntimeError.new("error 1")
      e2 = ArgumentError.new("error 2")
      exception = described_class.new([e1, e2])

      expect(exception.exceptions).to eq [e1, e2]
    end

    it "generates a message listing all exceptions" do
      e1 = RuntimeError.new("error 1")
      e2 = ArgumentError.new("error 2")
      exception = described_class.new([e1, e2])

      expect(exception.message).to include("2 exception(s) accumulated")
      expect(exception.message).to include("RuntimeError: error 1")
      expect(exception.message).to include("ArgumentError: error 2")
    end
  end
end

describe "Bunny::ExceptionAccumulator alias" do
  it "is an alias for Bunny::Concurrent::ExceptionAccumulator" do
    expect(Bunny::ExceptionAccumulator).to eq Bunny::Concurrent::ExceptionAccumulator
  end

  it "can be instantiated via the alias" do
    accumulator = Bunny::ExceptionAccumulator.new
    expect(accumulator).to be_a(Bunny::Concurrent::ExceptionAccumulator)
  end
end
