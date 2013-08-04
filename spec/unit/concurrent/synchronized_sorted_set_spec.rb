require "spec_helper"
require "bunny/concurrent/synchronized_sorted_set"

unless ENV["CI"]
  describe Bunny::Concurrent::SynchronizedSortedSet do
    50.times do |i|
      it "provides the same API as SortedSet for key operations (take #{i})" do
        s = described_class.new
        s.length.should == 0

        s << 1
        s.length.should == 1
        s << 1
        s.length.should == 1
        s << 2
        s.length.should == 2
        s << 3
        s.length.should == 3
        s << 4
        s.length.should == 4
        s << 4
        s << 4
        s << 4
        s.length.should == 4
        s << 5
        s.length.should == 5
        s << 5
        s << 5
        s << 5
        s.length.should == 5
        s << 6
        s.length.should == 6
        s << 7
        s.length.should == 7
        s << 8
        s.length.should == 8
        s.delete 8
        s.length.should == 7
        s.delete_if { |i| i == 1 }
        s.length.should == 6
      end
      it "synchronizes common operations needed by Bunny (take #{i})" do
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
        sleep 0.5

        s.length.should == 6
      end
    end
  end
end
