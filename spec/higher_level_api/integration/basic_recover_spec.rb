require "spec_helper"

describe Bunny::Channel, "#recover" do
  let(:connection) do
    c = Bunny.new
    c.start
    c
  end

  subject do
    connection.create_channel
  end

  it "is supported"
end
