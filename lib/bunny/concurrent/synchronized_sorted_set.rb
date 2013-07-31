require "set"
require "thread"

module Bunny
  module Concurrent
    class SynchronizedSortedSet < SortedSet
      def initialize(enum = nil)
        @mutex = Mutex.new

        super
      end

      def add(o)
        # avoid using Mutex#synchronize because of a Ruby 1.8.7-specific
        # bug that prevents super from being called from within a block. MK.
        @mutex.lock
        begin
          super
        ensure
          @mutex.unlock
        end
      end

      def delete(o)
        @mutex.lock
        begin
          super
        ensure
          @mutex.unlock
        end
      end

      def delete_if(&block)
        @mutex.lock
        begin
          super
        ensure
          @mutex.unlock
        end
      end

      def include?(o)
        @mutex.lock
        begin
          super
        ensure
          @mutex.unlock
        end
      end
    end
  end
end
