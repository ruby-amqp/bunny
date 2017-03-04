require "spec_helper"
require "bunny/concurrent/condition"

describe Bunny::Concurrent::Condition do

  describe "#wait" do
    50.times do |i|
      it "blocks current thread until notified (take #{i})" do
        condition = described_class.new
        xs        = []

        t = Thread.new do
          xs << :notified

          sleep 0.2
          condition.notify
        end
        t.abort_on_exception = true

        condition.wait
        expect(xs).to eq [:notified]
      end
    end
  end

  describe "#notify" do
    50.times do |i|
      it "notifies a single thread waiting on the latch (take #{i})" do
        mutex     = Mutex.new
        condition = described_class.new
        xs        = []

        t1 = Thread.new do
          condition.wait
          mutex.synchronize { xs << :notified1 }
        end
        t1.abort_on_exception = true

        t2 = Thread.new do
          condition.wait
          mutex.synchronize { xs << :notified2 }
        end
        t2.abort_on_exception = true

        sleep 0.2
        condition.notify
        sleep 0.5
        expect(xs).to satisfy { |ys| ys.size == 1 && (ys.include?(:notified1) || ys.include?(:notified2)) }
      end
    end
  end

  describe "#notify_all" do
    let(:n) { 30 }

    50.times do |i|
      it "notifies all the threads waiting on the latch (take #{i})" do
        mutex     = Mutex.new
        condition = described_class.new
        @xs       = []

        n.times do |i|
          t = Thread.new do
            condition.wait
            mutex.synchronize { @xs << "notified#{i + 1}".to_sym }
          end
          t.abort_on_exception = true
        end

        sleep 0.5
        condition.notify_all
        sleep 0.5

        n.times do |i|
          item = "notified#{i + 1}".to_sym

          expect(@xs).to include item
        end
      end
    end
  end
end
