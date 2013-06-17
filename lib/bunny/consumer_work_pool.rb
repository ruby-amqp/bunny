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

      @started = true
    end

    def started?
      @started
    end

    def shutdown
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
      @threads.each { |t| t.stop }
    end

    def resume
      @threads.each { |t| t.run }
    end

    def kill
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
