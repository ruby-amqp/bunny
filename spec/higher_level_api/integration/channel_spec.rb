require "spec_helper"

describe Bunny::Channel do
  let(:connection) { Bunny.new }

  before :all do
    connection.start
  end

  after :all do
    connection.close
  end

  context "open without explicitly provided id" do
    subject do
      ch = connection.create_channel
      ch.open
      ch
    end

    it "gets an allocated id and is successfully opened" do
      connection.should be_connected
      subject.should be_open

      subject.id.should be > 0
    end
  end
end
