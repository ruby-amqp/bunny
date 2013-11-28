require "spec_helper"

describe Bunny::Channel, "when opened" do
  let(:connection) do
    c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed")
    c.start
    c
  end

  after :each do
    connection.close
  end

  context "without explicitly provided id" do
    it "gets an allocated id and is successfully opened" do
      connection.should be_connected
      ch = connection.create_channel
      ch.should be_open

      ch.id.should be > 0
    end
  end

  context "with an explicitly provided id = 0" do
    it "raises ArgumentError" do
      connection.should be_connected
      expect {
        connection.create_channel(0)
      }.to raise_error(ArgumentError)
    end
  end


  context "with explicitly provided id" do
    it "uses that id and is successfully opened" do
      ch = connection.create_channel(767)
      connection.should be_connected
      ch.should be_open

      ch.id.should == 767
    end
  end



  context "with explicitly provided id that is already taken" do
    it "reuses the channel that is already opened" do
      ch = connection.create_channel(767)
      connection.should be_connected
      ch.should be_open

      ch.id.should == 767

      connection.create_channel(767).should == ch
    end
  end
end
