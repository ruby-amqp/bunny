# -*- encoding: utf-8; mode: ruby -*-

require "system_timer"

module Bunny
  # Used for Ruby before 1.9
  class SystemTimer
    # Executes a block of code, raising if the execution does not finish
    # in the alloted period of time, in seconds.
    def self.timeout(seconds, exception = nil)
      if seconds
        ::SystemTimer.timeout_after(seconds, exception) do
          yield
        end
      else
        yield
      end
    end
  end # SystemTimer
end # Bunny
