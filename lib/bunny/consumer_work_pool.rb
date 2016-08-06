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
    attr_reader :abort_on_exception

    def initialize(size = 1, abort_on_exception = false)
      @size  = size
      @abort_on_exception = abort_on_exception
      @queue = ::Queue.new
      @paused = false
    end


    def submit(callable = nil, &block)
      @queue.push(callable || block)
    end

    def start
      @threads = []

      @size.times do
        t = Thread.new(&method(:run_loop))
        t.abort_on_exception = true if abort_on_exception
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
    end

    def join(timeout = nil)
      (@threads || []).each { |t| t.join(timeout) }
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

      (@threads || []).each { |t| t.kill }
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
    end
  end
end
