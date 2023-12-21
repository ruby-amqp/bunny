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
        timeout_in_sec = timeout_in_ms ? timeout_in_ms / 1000.0 : nil

        @lock.synchronize do
          started_at = Bunny::Timestamp.monotonic
          while @q.empty?
            wait = !(timeout_in_sec.nil?)
            @cond.wait(@lock, timeout_in_sec)

            if wait
              ended_at = Bunny::Timestamp.monotonic
              elapsed = ended_at - started_at
              raise ::Timeout::Error if (elapsed > timeout_in_sec)
            end
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
