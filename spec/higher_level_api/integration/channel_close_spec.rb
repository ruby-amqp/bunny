require "spec_helper"

describe Bunny::Channel, "when closed" do
  let(:connection) do
    c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed")
    c.start
    c
  end

  after :all do
    connection.close
  end


  subject do
    connection.create_channel
  end

  it "releases the id" do
    n = subject.number

    subject.should be_open
    subject.close
    subject.should be_closed

    # a new channel with the same id can be created
    connection.create_channel(n)
  end
end
