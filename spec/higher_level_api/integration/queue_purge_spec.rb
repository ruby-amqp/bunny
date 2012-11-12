require "spec_helper"

describe Bunny::Queue do
  let(:connection) do
    c = Bunny.new
    c.start
    c
  end

  it "can be purged"
end
