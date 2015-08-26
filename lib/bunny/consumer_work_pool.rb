require "thread"

module Bunny
  # Thread pool that dispatches consumer deliveries. Not supposed to be shared between channels
  # or threads.
  #
  # Every channel its own consumer pool.
  #
  # @private
  class ConsumerWorkPool

    #
    # API
    #

    attr_reader :threads
    attr_reader :size

    def initialize(size = 1, shutdown_timeout=nil)
      @size  = size
      @queue = ::Queue.new
      @paused = false
      # Attributes to handle clean reliable shutdown of the workpool
      @shutdown_timeout = shutdown_timeout
      @shutdown_mutex = Mutex.new
      @shutdown_conditional = ConditionalVariable.new
    end


    def submit(callable = nil, &block)
      @queue.push(callable || block)
    end

    def start
      @threads = []

      @size.times do
        t = Thread.new(&method(:run_loop))
        @threads << t
      end

      @running = true
    end

    def running?
      @running
    end

    def backlog
      @queue.length
    end

    def busy?
      !@queue.empty?
    end

    def shutdown
      @running = false

      @size.times do
        submit do |*args|
          throw :terminate
        end
      end
      @shutdown_mutex.synchronize do
        @shutdown_conditional.wait(@shutdown_mutex,@shutdown_timeout)
      end
    end

    def join(timeout = nil)
      @threads.each { |t| t.join(timeout) }
    end

    def pause
      @running = false
      @paused = true
    end

    def resume
      @running = true
      @paused = false

      @threads.each { |t| t.run }
    end

    def kill
      @running = false

      @threads.each { |t| t.kill }
    end

    protected

    def run_loop
      catch(:terminate) do
        loop do
          Thread.stop if @paused
          callable = @queue.pop

          begin
            callable.call
          rescue ::StandardError => e
            # TODO: use connection logger
            $stderr.puts e.class.name
            $stderr.puts e.message
          end
        end
      end
      @shutdown_mutex.synchronize do
        @shutdown_conditional.signal unless busy?
      end
    end
  end
end
