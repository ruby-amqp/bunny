require "spec_helper"

describe Bunny::Session do
  n = if RUBY_ENGINE == "jruby"
        100
      else
        4000
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
