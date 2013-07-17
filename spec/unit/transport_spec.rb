require "spec_helper"

# mystically fails on Rubinius on CI. MK.
if RUBY_ENGINE != "rbx"
  describe Bunny::Transport, ".reachable?" do
    it "returns true for rabbitmq.com, 80" do
      Bunny::Transport.reacheable?("rabbitmq.com", 80, 1).should be_true
    end

    it "returns true for rabbitmq.com, 18088" do
      Bunny::Transport.reacheable?("rabbitmq.com", 18088, 1).should be_false
    end

    it "returns false for google1237982792837.com, 8277" do
      Bunny::Transport.reacheable?("google1237982792837.com", 8277, 1).should be_false
    end
  end
end
