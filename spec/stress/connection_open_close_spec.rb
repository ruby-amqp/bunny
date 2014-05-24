require "spec_helper"

unless defined?(JRUBY_VERSION) && !ENV["FORCE_JRUBY_RUN"]
  describe Bunny::Session do
    # creating thousands of connections means creating
    # twice as many threads and this won't fly with the JVM
    # in CI containers. MK.
    n = if defined?(JRUBY_VERSION)
          250
        else
          2500
        end

    n.times do |i|
      it "can be closed (automatic recovery disabled, take #{i})" do
        c  = Bunny.new(:automatically_recover => false)
        c.start
        ch = c.create_channel

        c.should be_connected
        c.stop
        c.should be_closed
      end
    end

    n.times do |i|
      it "can be closed in the Hello, World example (take #{i})" do
        c  = Bunny.new(:automatically_recover => false)
        c.start
        ch = c.create_channel
        x  = ch.default_exchange
        q  = ch.queue("", :exclusive => true)
        q.subscribe do |delivery_info, properties, payload|
          # no-op
        end
        20.times { x.publish("hello", :routing_key => q.name) }

        c.should be_connected
        c.stop
        c.should be_closed
      end
    end

    n.times do |i|
      it "can be closed (automatic recovery enabled, take #{i})" do
        c  = Bunny.new(:automatically_recover => true)
        c.start
        ch = c.create_channel

        c.should be_connected
        c.stop
        c.should be_closed
      end
    end

    context "in the single threaded mode" do
      n.times do |i|
        it "can be closed (single threaded mode, take #{i})" do
          c  = Bunny.new(:automatically_recover => false, :threaded => false)
          c.start
          ch = c.create_channel

          c.should be_connected
          c.stop
          c.should be_closed
        end
      end
    end
  end
end
