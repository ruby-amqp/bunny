require "spec_helper"

describe Bunny::Channel, "when opened" do
  let(:connection) do
    c = Bunny.new(username: "bunny_gem", password: "bunny_password", vhost: "bunny_testbed")
    c.start
    c
  end

  after :each do
    connection.close
  end

  context "without explicitly provided id" do
    it "gets an allocated id and is successfully opened" do
      expect(connection).to be_connected
      ch = connection.create_channel
      expect(ch).to be_open

      expect(ch.id).to be > 0
    end
  end

  context "with an explicitly provided id = 0" do
    it "raises ArgumentError" do
      expect(connection).to be_connected
      expect {
        connection.create_channel(0)
      }.to raise_error(ArgumentError)
    end
  end


  context "with explicitly provided id" do
    it "uses that id and is successfully opened" do
      ch = connection.create_channel(767)
      expect(connection).to be_connected
      expect(ch).to be_open

      expect(ch.id).to eq 767
    end
  end



  context "with explicitly provided id that is already taken" do
    it "reuses the channel that is already opened" do
      ch = connection.create_channel(767)
      expect(connection).to be_connected
      expect(ch).to be_open

      expect(ch.id).to eq 767

      expect(connection.create_channel(767)).to eq ch
    end
  end
end
