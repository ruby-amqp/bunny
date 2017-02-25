require "spec_helper"

describe Bunny::Channel, "#tx_commit" do
  let(:connection) do
    c = Bunny.new(username: "bunny_gem", password: "bunny_password", vhost: "bunny_testbed")
    c.start
    c
  end

  after :each do
    connection.close if connection.open?
  end

  it "is supported" do
    ch = connection.create_channel
    ch.tx_select
    ch.tx_commit

    ch.close
  end
end
