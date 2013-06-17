require "spec_helper"

describe "Client-defined heartbeat interval" do
  let(:connection) do
    c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed", :heartbeat_interval => 4)
    c.start
    c
  end

  it "can be enabled explicitly" do
    sleep 5.0

    connection.close
  end
end


describe "Server-defined heartbeat interval" do
  let(:connection) do
    c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed", :heartbeat_interval => :server)
    c.start
    c
  end

  it "can be enabled explicitly" do
    puts "Sleeping for 5 seconds with heartbeat interval of 4"
    sleep 5.0

    connection.close
  end
end
