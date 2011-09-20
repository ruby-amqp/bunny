# encoding: utf-8

module Bunny
  # Used for ruby < 1.9.x
  class SystemTimer < ::SystemTimer

    def timeout(seconds, exception)
      timeout_after(seconds) do
        yield
      end
    end

  end
end