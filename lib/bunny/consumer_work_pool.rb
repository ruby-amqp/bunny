require "thread"

module Bunny
  # Thread pool that dispatches consumer deliveries. Not supposed to be shared between channels
  # or threads.
  #
  # @private
  class ConsumerWorkPool

    #
    # API
    #

    attr_reader :size

    def initialize(size = 1)
      @size  = size
      @queue = ::Queue.new
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

    def shutdown
      @running = false

      @size.times do
        submit do |*args|
          throw :terminate
        end
      end
    end

    def join
      @threads.each { |t| t.join }
    end

    def pause
      @running = false

      @threads.each { |t| t.stop }
    end

    def resume
      @running = true

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
          callable = @queue.pop

          begin
            callable.call
          rescue Exception => e
            # TODO
            puts e.class.name
            puts e.message
          end
        end
      end
    end
  end
end
