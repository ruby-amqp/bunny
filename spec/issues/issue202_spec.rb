require "spec_helper"

describe Bunny::Session do
  context "with unreachable host" do
    it "raises Bunny::TCPConnectionFailed" do
      begin
        conn = Bunny.new(:hostname => "192.192.192.192")
        conn.start

        false.should be(true)
      rescue Bunny::TCPConnectionFailed => e
      end
    end
  end
end
