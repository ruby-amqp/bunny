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

  let(:n) { 100 }

  it "works correctly in a single-threaded scenario" do
    xs = Array.new(n) { connection.create_channel }
    puts "Opened #{n} channels"

    xs.size.should == n
    xs.each do |ch|
      ch.close
    end
  end

  it "works correctly in a multi-threaded scenario" do
    n.times do
      t = Thread.new do
        ch = connection.create_channel

        ch.close
      end
      t.abort_on_exception = true
    end
  end
end
