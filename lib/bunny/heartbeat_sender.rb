require "thread"
require "amq/protocol/client"
require "amq/protocol/frame"

module Bunny
  class HeartbeatSender

    #
    # API
    #

    def initialize(session)
      @session = session
      @mutex   = Mutex.new

      @last_activity_time = Time.now
    end

    def start(period = 30)
      @mutex.synchronize do
        @period = period

        @thread = Thread.new(&method(:run))
      end
    end

    def stop
      @mutex.synchronize { @thread.exit }
    end

    def signal_activity!
      @last_activity_time = Time.now
    end

    protected

    def run
      begin
        loop do
          self.beat

          sleep (@period / 2)
        end
      rescue IOError => ioe
        # ignored
      rescue Exception => e
        puts e.message
      end
    end

    def beat
      now = Time.now

      if now > (@last_activity_time + @period)
        @session.send_raw(AMQ::Protocol::HeartbeatFrame.encode)
      end
    end
  end
end
