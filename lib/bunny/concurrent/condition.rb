require "thread"

module Bunny
  module Concurrent
    # Akin to java.util.concurrent.Condition and intrinsic object monitors (Object#wait, Object#notify, Object#notifyAll) in Java:
    # threads can wait (block until notified) on a condition other threads notify them about.
    # Unlike the j.u.c. version, this one has a single waiting set.
    class Condition
      attr_reader :waiting_threads


      def initialize
        @mutex           = Mutex.new
        @waiting_threads = []
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
          t = @waiting_threads.delete_at(0)
          t.run if t
        end
      end

      def notify_all
        @mutex.synchronize do
          puts "About to notify #{@waiting_threads.size} threads..."
          @waiting_threads.each do |t|
            t.run
          end

          @waiting_threads = []
        end
      end

      def waiting_set_size
        @mutex.synchronize { @waiting_threads.size }
      end
    end
  end
end
