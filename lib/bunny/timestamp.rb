module Bunny
  # Abstracts away the Ruby (OS) method of retriving timestamps.
  #
  # @private
  class Timestamp
    def self.now
      ::Time.now
    end

    def self.monotonic
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def self.non_monotonic
      ::Time.now
    end

    def self.non_monotonic_utc
      self.non_monotonic.utc
    end
  end
end