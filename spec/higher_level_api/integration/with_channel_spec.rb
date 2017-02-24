require "spec_helper"

describe Bunny::Channel, "#with_channel" do
  let(:connection) do
    c = Bunny.new(username: "bunny_gem", password: "bunny_password", vhost: "bunny_testbed")
    c.start
    c
  end

  after :each do
    connection.close if connection.open?
  end

  it "closes if the block throws an exception" do
    ch = nil
    begin
      connection.with_channel do |wch|
        ch = wch
        raise Exception.new
      end
    rescue Exception
    end
    expect(ch).to be_closed
  end
end
