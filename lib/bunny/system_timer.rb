# -*- encoding: utf-8; mode: ruby -*-

require "system_timer"

module Bunny
  # Used for Ruby before 1.9
  class SystemTimer < ::SystemTimer
    def timeout(seconds, exception)
      timeout_after(seconds) do
        yield
      end
    end
  end # SystemTimer
end # Bunny
