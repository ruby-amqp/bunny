require "spec_helper"

describe "Rapidly opening and closing lots of channels" do
  let(:connection) do
    c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed")
    c.start
    c
  end

  after :all do
    connection.close
  end

  it "works correctly" do
    xs = Array.new(2000) { connection.create_channel }

    xs.size.should == 2000
    xs.each do |ch|
      ch.close
    end
  end
end
