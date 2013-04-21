require "thread"

module Bunny
  module Concurrent
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

      def clear
        @q.clear
      end

      def method_missing(selector, *args, &block)
        @q.__send__(selector, *args, &block)
      end
    end
  end
end
