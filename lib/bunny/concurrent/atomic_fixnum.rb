require "set"
require "thread"
require "monitor"

module Bunny
  module Concurrent
    # Minimalistic implementation of a synchronized fixnum value,
    # designed after (but not implementing the entire API of!)
    #
    # @note Designed to be intentionally minimalistic and only cover Bunny's needs.
    #
    # @api public
    class AtomicFixnum
      def initialize(n = 0)
        @n     = n
        @mutex = Monitor.new
      end

      def get
        @mutex.synchronize do
          @n
        end
      end
      alias to_i get

      def set(n)
        @mutex.synchronize do
          @n = n
        end
      end

      def increment
        @mutex.synchronize do
          @n = @n + 1
        end
      end
      alias inc increment
      alias increment_and_get increment

      def get_and_add(i)
        @mutex.synchronize do
          v = @n
          @n = @n + i

          v
        end
      end

      def get_and_increment
        @mutex.synchronize do
          v = @n
          @n = @n + 1

          v
        end
      end

      def decrement
        @mutex.synchronize do
          @n = @n - 1
        end
      end
      alias dec decrement
      alias decrement_and_get decrement

      def ==(m)
        @mutex.synchronize { @n == m }
      end

      def ===(v)
        @mutex.synchronize { @n === v }
      end
    end
  end
end
