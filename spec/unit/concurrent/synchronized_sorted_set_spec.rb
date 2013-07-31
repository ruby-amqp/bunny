require "spec_helper"
require "bunny/concurrent/synchronized_sorted_set"

describe Bunny::Concurrent::SynchronizedSortedSet do
  it "synchronizes common operations needed by Bunny" do
    subject.length.should == 0

    10.times do
      Thread.new do
        subject << 1
        subject << 1
        subject << 2
        subject << 3
        subject << 4
        subject << 4
        subject << 4
        subject << 4
        subject << 5
        subject << 5
        subject << 5
        subject << 5
        subject << 6
        subject << 7
        subject << 8
        subject.delete 8
        subject.delete_if { |i| i == 1 }
      end
    end

    subject.length.should == 6
  end
end
