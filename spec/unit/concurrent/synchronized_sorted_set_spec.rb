require "spec_helper"
require "bunny/concurrent/synchronized_sorted_set"

unless ENV["CI"]
  describe Bunny::Concurrent::SynchronizedSortedSet do
    50.times do |i|
      it "provides the same API as SortedSet for key operations (take #{i})" do
        s = described_class.new
        expect(s.length).to eq 0

        s << 1
        expect(s.length).to eq 1
        s << 1
        expect(s.length).to eq 1
        s << 2
        expect(s.length).to eq 2
        s << 3
        expect(s.length).to eq 3
        s << 4
        expect(s.length).to eq 4
        s << 4
        s << 4
        s << 4
        expect(s.length).to eq 4
        s << 5
        expect(s.length).to eq 5
        s << 5
        s << 5
        s << 5
        expect(s.length).to eq 5
        s << 6
        expect(s.length).to eq 6
        s << 7
        expect(s.length).to eq 7
        s << 8
        expect(s.length).to eq 8
        s.delete 8
        expect(s.length).to eq 7
        s.delete_if { |i| i == 1 }
        expect(s.length).to eq 6
      end
      it "synchronizes common operations needed by Bunny (take #{i})" do
        s = described_class.new
        expect(s.length).to eq 0

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

        expect(s.length).to eq 6
      end
    end
  end
end
