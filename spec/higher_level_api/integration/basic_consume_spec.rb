require "spec_helper"

describe Bunny::Queue, "#subscribe" do
  let(:connection) do
    c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed")
    c.start
    c
  end

  after :all do
    connection.close if connection.open?
  end

  context "with automatic acknowledgement mode" do
  end

  context "with manual acknowledgement mode" do
  end
end
