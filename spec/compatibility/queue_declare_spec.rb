require "spec_helper"

describe Bunny::Queue, "backwards compatibility API" do
  let(:connection) do
    c = Bunny.new
    c.start
    c
  end

  after :all do
    connection.close if connection.open?
  end

  context "when queue name is specified" do
    let(:name) { "a queue declared at #{Time.now.to_i}" }

    it "declares a new queue with that name" do
      q    = Bunny::Queue.new(connection, name)
      q.name.should == name
    end
  end


  context "when queue name is passed on as an empty string" do
    it "uses server-assigned queue name" do
      q = Bunny::Queue.new(connection, "")
      q.name.should_not be_empty
      q.name.should =~ /^amq.gen.+/
      q.should be_server_named
      q.delete
    end
  end


  context "when queue name is completely omitted" do
    it "uses server-assigned queue name" do
      q = Bunny::Queue.new(connection)
      q.name.should_not be_empty
      q.name.should =~ /^amq.gen.+/
      q.should be_server_named
      q.delete
    end
  end
end
