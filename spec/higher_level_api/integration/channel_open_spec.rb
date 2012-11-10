require "spec_helper"

describe Bunny::Channel, "when opened" do
  let(:connection) { Bunny.new }

  before :all do
    connection.start
  end

  after :all do
    connection.close
  end

  context "without explicitly provided id" do
    subject do
      connection.create_channel
    end

    it "gets an allocated id and is successfully opened" do
      connection.should be_connected
      subject.should be_open

      subject.id.should be > 0
    end
  end


  context "with explicitly provided id" do
    subject do
      connection.create_channel(767)
    end

    it "uses that id and is successfully opened" do
      connection.should be_connected
      subject.should be_open

      subject.id.should == 767
    end
  end
end
