require "spec_helper"

unless ENV["CI"]
  describe Bunny::Session do
    context "with unreachable host" do
      it "raises Bunny::TCPConnectionFailed" do
        begin
          conn = Bunny.new(hostname: "127.0.0.254", port: 1433, connection_timeout: 2)
          conn.start

          fail "expected 192.192.192.192 to be unreachable"
        rescue Bunny::TCPConnectionFailed => e
        end
      end
    end
  end
end