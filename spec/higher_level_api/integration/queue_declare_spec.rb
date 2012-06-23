require "spec_helper"

describe Bunny::Queue do
  context "when queue name is specified" do
    let(:name) { "a queue declared at #{Time.now.to_i}" }

    it "declares a new queue with that name" do
      conn = Bunny.new
      conn.start

      ch   = conn.create_channel
      ch.open

      q    = ch.queue(name)
      q.name.should == name

      conn.close
    end

    it "caches that queue" do
      conn = Bunny.new
      conn.start

      ch   = conn.create_channel
      ch.open

      q = ch.queue(name)
      ch.queue(name).object_id.should == q.object_id

      conn.close
    end
  end


  context "when queue name is passed on as an empty string" do
    it "uses server-assigned queue name" do
      conn = Bunny.new
      conn.start

      ch   = conn.create_channel
      ch.open

      q = ch.queue("")
      q.name.should_not be_empty
      q.delete

      conn.close
    end
  end
end
