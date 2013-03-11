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

  let(:n) { 200 }

  it "works correctly" do
    xs = Array.new(n) { connection.create_channel }

    puts "Opened #{n} channels"

    xs.size.should == n
    xs.each do |ch|
      ch.close
    end
  end
end
