require "spec_helper"

describe Bunny::Channel, "#confirm_select" do
  let(:connection) do
    c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed")
    c.start
    c
  end

  after :each do
    connection.close if connection.open?
  end

  it "is supported" do
    connection.with_channel do |ch|
      ch.confirm_select
    end
  end
end
