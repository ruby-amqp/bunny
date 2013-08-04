require "spec_helper"

unless RUBY_ENGINE == "jruby" && !ENV["FORCE_JRUBY_RUN"]
  describe Bunny::Session do
    # creating thousands of connections means creating
    # twice as many threads and this won't fly with the JVM
    # in CI containers. MK.
    n = if RUBY_ENGINE == "jruby"
          100
        else
          5000
        end

    n.times do |i|
      it "can be closed (take #{i})" do
        c  = Bunny.new(:automatically_recover => false)
        c.start
        ch = c.create_channel

        c.should be_connected
        c.stop
        c.should be_closed
      end
    end
  end
end
