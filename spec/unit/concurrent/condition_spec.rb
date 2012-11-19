require "spec_helper"
require "bunny/concurrent/condition"

describe Bunny::Concurrent::Condition do
  describe "#wait" do
    it "blocks current thread until notified" do
      condition = described_class.new
      xs        = []

      t = Thread.new do
        xs << :notified

        sleep 0.25
        subject.notify
      end

      subject.wait
      xs.should == [:notified]
    end
  end

  describe "#notify" do
    it "notifies a single thread waiting on the latch" do
      condition = described_class.new
      xs        = []

      t1 = Thread.new do
        subject.wait
        xs << :notified1
      end

      t2 = Thread.new do
        subject.wait
        xs << :notified2
      end

      sleep 0.25
      subject.notify
      sleep 0.5
      xs.should satisfy { |ys| ys.size == 1 && (ys.include?(:notified1) || ys.include?(:notified2)) }
    end
  end

  describe "#notify_all" do
    it "notifies all the threads waiting on the latch" do
      condition = described_class.new
      @xs        = []

      t1 = Thread.new do
        subject.wait
        @xs << :notified1
      end
      sleep 1.0

      t2 = Thread.new do
        subject.wait
        @xs << :notified2
      end

      sleep 0.5
      subject.notify_all
      sleep 1.5
      @xs.should include(:notified1)
      @xs.should include(:notified2)
    end
  end
end
