# -*- encoding: utf-8; mode: ruby -*-

require "system_timer"

module Bunny
  # Used for Ruby before 1.9
  class SystemTimer
    def self.timeout(seconds, exception)
      if seconds
        ::SystemTimer.timeout_after(seconds) do
          yield
        end
      else
        yield
      end
    end
  end # SystemTimer
end # Bunny
