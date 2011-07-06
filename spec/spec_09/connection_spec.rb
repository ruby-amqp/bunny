# encoding: utf-8

# connection_spec.rb

require "bunny"

describe Bunny do

  it "should raise an error if the wrong user name or password is used" do
    b = Bunny.new(:spec => '0.9', :user => 'wrong')
    lambda { b.start}.should raise_error(Bunny::ProtocolError)
  end

end
