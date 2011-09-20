# encoding: utf-8

# connection_spec.rb

require File.expand_path(File.join(File.dirname(__FILE__), %w[.. .. lib bunny]))

describe Bunny do

  it "should raise an error if the wrong user name or password is used" do
    b = Bunny.new(:user => 'wrong')
    lambda { b.start}.should raise_error(Bunny::ProtocolError)
  end

  it "should be able to open a TCPSocket with a timeout" do
    b = Bunny.new(:spec => "0.8")
    connect_timeout = 1
    lambda { 
      Bunny::Timer::timeout(connect_timeout, Qrack::ConnectionTimeout) do
        TCPSocket.new(b.host, b.port) 
      end
    }.should_not raise_error(Exception)
  end

end

