require "spec_helper"

describe Bunny::Session do
  4000.times do |i|
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
