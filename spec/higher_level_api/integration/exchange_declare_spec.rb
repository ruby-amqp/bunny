require "spec_helper"

describe Bunny::Exchange do
  let(:connection) do
    c = Bunny.new
    c.start
    c
  end


  context "of type fanout" do
    context "with a non-predefined name" do
      it "is declared" do
        ch = connection.create_channel
        ch.open

        name = "bunny.tests.exchages.fanout"
        x    = ch.fanout(name)
        x.name.should == name

        ch.close
      end
    end
  end

  context "of type direct" do
  end

  context "of type topic" do
  end

  context "of type headers" do
  end
end
