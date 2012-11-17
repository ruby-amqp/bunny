require "spec_helper"

describe Bunny::Queue, "bound to an exchange" do
  let(:connection) do
    c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed")
    c.start
    c
  end

  after :all do
    connection.close
  end


  it "can be unbound from an exchange it was bound to"
end



describe Bunny::Queue, "NOT bound to an exchange" do
  let(:connection) do
    c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed")
    c.start
    c
  end

  after :all do
    connection.close
  end


  it "cannot be unbound (raises a channel error)"
end
