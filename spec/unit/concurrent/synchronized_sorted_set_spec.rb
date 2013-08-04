require "spec_helper"
require "bunny/concurrent/synchronized_sorted_set"

unless ENV["CI"]
  describe Bunny::Concurrent::SynchronizedSortedSet do
    it "synchronizes common operations needed by Bunny" do
      s = described_class.new
      s.length.should == 0

      10.times do
        Thread.new do
          s << 1
          s << 1
          s << 2
          s << 3
          s << 4
          s << 4
          s << 4
          s << 4
          s << 5
          s << 5
          s << 5
          s << 5
          s << 6
          s << 7
          s << 8
          s.delete 8
          s.delete_if { |i| i == 1 }
        end
      end
      sleep 2.0

      s.length.should == 6
    end
  end
end
