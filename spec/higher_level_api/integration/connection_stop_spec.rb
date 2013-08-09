require "spec_helper"

describe Bunny::Session do
  it "can be closed" do
    c  = Bunny.new(:automatically_recover => false)
    c.start
    ch = c.create_channel

    c.should be_connected
    c.stop
    c.should be_closed
  end
end


describe Bunny::Session, "in a single threaded mode" do
  it "can be closed" do
    c  = Bunny.new(:automatically_recover => false, :threaded => false)
    c.start
    ch = c.create_channel

    c.should be_connected
    c.stop
    c.should be_closed
  end
end
