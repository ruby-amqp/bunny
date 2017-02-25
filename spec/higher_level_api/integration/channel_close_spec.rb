require "spec_helper"

describe Bunny::Channel, "when closed" do
  let(:connection) do
    c = Bunny.new(username: "bunny_gem", password: "bunny_password", vhost: "bunny_testbed")
    c.start
    c
  end

  after :each do
    connection.close
  end

  it "releases the id" do
    ch = connection.create_channel
    n = ch.number

    expect(ch).to be_open
    ch.close
    expect(ch).to be_closed

    # a new channel with the same id can be created
    connection.create_channel(n)
  end
end
