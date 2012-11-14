require "thread"

module Bunny
  # Akin to intrinsic object monitors and Object#wait, Object#notify, Object#notifyAll in Java:
  # threads can wait (block until notified) on a condition other threads notify them about.
  class WaitNotifyLatch
    def initialize
      # Ruby's ConditionVariable requires a mutex to accompany it :/
      @mutex           = Mutex.new
      @waiting_threads = []
    end

    def wait
      @mutex.synchronize do
        @waiting_threads << Thread.current
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
        @waiting_threads.each do |t|
          t.run
        end

        @waiting_threads = []
      end
    end
  end
end
