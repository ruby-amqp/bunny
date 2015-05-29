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
          if @q.empty?
            @cond.wait(@lock, timeout)
            raise ::Timeout::Error if @q.empty?
          end
          item = @q.shift
          @cond.signal

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
