require "thread"

module Bunny
  module Concurrent
    # Continuation queue implementation for MRI and Rubinius
    #
    # @private
    class ContinuationQueue
      def initialize
        @q    = []
        @lock = ::Mutex.new
        @cond = ::ConditionVariable.new
      end

      def push(item)
        @lock.synchronize do
          @q.push(item)
          @cond.signal
        end
      end
      alias << push

      def pop
        poll
      end

      def poll(timeout_in_ms = nil)
        timeout = timeout_in_ms ? timeout_in_ms / 1000.0 : nil

        @lock.synchronize do
          timeout_strikes_at = Time.now.utc + (timeout || 0)
          while @q.empty?
            wait = if timeout
                     timeout_strikes_at - Time.now.utc
                   else
                     nil
                   end
            @cond.wait(@lock, wait)
            raise ::Timeout::Error if wait && Time.now.utc >= timeout_strikes_at
          end
          item = @q.shift
          item
        end
      end

      def clear
        @lock.synchronize do
          @q.clear
        end
      end

      def empty?
        @q.empty?
      end

      def size
        @q.size
      end
      alias length size
    end
  end
end
