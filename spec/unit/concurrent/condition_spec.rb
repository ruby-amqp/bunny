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
        condition.notify
      end
      t.abort_on_exception = true

      condition.wait
      xs.should == [:notified]
    end
  end

  describe "#notify" do
    it "notifies a single thread waiting on the latch" do
      condition = described_class.new
      xs        = []

      t1 = Thread.new do
        condition.wait
        xs << :notified1
      end
      t1.abort_on_exception = true

      t2 = Thread.new do
        condition.wait
        xs << :notified2
      end
      t2.abort_on_exception = true

      sleep 0.25
      condition.notify
      sleep 0.5
      xs.should satisfy { |ys| ys.size == 1 && (ys.include?(:notified1) || ys.include?(:notified2)) }
    end
  end

  describe "#notify_all" do
    it "notifies all the threads waiting on the latch" do
      condition = described_class.new
      @xs        = []

      t1 = Thread.new do
        condition.wait
        @xs << :notified1
      end
      t1.abort_on_exception = true

      t2 = Thread.new do
        condition.wait
        @xs << :notified2
      end
      t2.abort_on_exception = true

      sleep 0.5
      condition.notify_all
      sleep 0.5
      @xs.should include(:notified1)
      @xs.should include(:notified2)
    end
  end
end
