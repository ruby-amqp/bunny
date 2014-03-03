require "thread"

module Bunny
  module Concurrent
    # Continuation queue implementation for MRI and Rubinius
    #
    # @private
    class ContinuationQueue
      def initialize(*args, &block)
        @q = ::Queue.new(*args)
      end

      def push(*args)
        @q.push(*args)
      end
      alias << push

      def pop
        @q.pop
      end

      def poll(timeout_in_ms = nil)
        if timeout_in_ms
          Bunny::Timeout.timeout(timeout_in_ms / 1000.0, ::Timeout::Error) do
            @q.pop
          end
        else
          @q.pop
        end
      end

      def clear
        @q.clear
      end

      def method_missing(selector, *args, &block)
        @q.__send__(selector, *args, &block)
      end
    end
  end
end
