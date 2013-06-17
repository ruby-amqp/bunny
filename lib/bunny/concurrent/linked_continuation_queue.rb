if !defined?(JRUBY_VERSION)
  raise "Bunny::Concurrent::LinkedContinuationQueue can only be used on JRuby!"
end

require "java"

java_import java.util.concurrent.LinkedBlockingQueue
java_import java.util.concurrent.TimeUnit

module Bunny
  module Concurrent
    # Continuation queue implementation for JRuby.
    #
    # On JRuby, we'd rather use reliable and heavily battle tested j.u.c.
    # primitives with well described semantics than informally specified, clumsy
    # and limited Ruby standard library parts.
    #
    # This is an implementation of the continuation queue on top of the linked blocking
    # queue in j.u.c.
    #
    # Compared to the Ruby standard library Queue, there is one limitation: you cannot
    # push a nil on the queue, it will fail with a null pointer exception.
    # @private
    class LinkedContinuationQueue
      def initialize(*args, &block)
        @q = LinkedBlockingQueue.new
      end

      def push(el, timeout_in_ms = nil)
        if timeout_in_ms
          @q.offer(el, timeout_in_ms, TimeUnit::MILLISECONDS)
        else
          @q.offer(el)
        end
      end
      alias << push

      def pop
        @q.take
      end

      def poll(timeout_in_ms = nil)
        if timeout_in_ms
          v = @q.poll(timeout_in_ms, TimeUnit::MILLISECONDS)
          raise ::Timeout::Error.new("operation did not finish in #{timeout_in_ms} ms") if v.nil?
          v
        else
          @q.poll
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
