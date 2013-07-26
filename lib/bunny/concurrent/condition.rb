require "thread"
require "monitor"

module Bunny
  # @private
  module Concurrent
    # Akin to java.util.concurrent.Condition and intrinsic object monitors (Object#wait, Object#notify, Object#notifyAll) in Java:
    # threads can wait (block until notified) on a condition other threads notify them about.
    # Unlike the j.u.c. version, this one has a single waiting set.
    #
    # Conditions can optionally be annotated with a description string for ease of debugging.
    # @private
    class Condition
      attr_reader :waiting_threads, :description


      def initialize(description = nil)
        @mutex           = Monitor.new
        @waiting_threads = []
        @description     = description
      end

      def wait
        @mutex.synchronize do
          t = Thread.current
          @waiting_threads.push(t)
        end

        Thread.stop
      end

      def notify
        @mutex.synchronize do
          t = @waiting_threads.shift
          begin
            t.run if t
          rescue ThreadError
            retry
          end
        end
      end

      def notify_all
        @mutex.synchronize do
          @waiting_threads.each do |t|
            t.run
          end

          @waiting_threads.clear
        end
      end

      def waiting_set_size
        @mutex.synchronize { @waiting_threads.size }
      end

      def any_threads_waiting?
        @mutex.synchronize { !@waiting_threads.empty? }
      end

      def none_threads_waiting?
        @mutex.synchronize { @waiting_threads.empty? }
      end
    end
  end
end
