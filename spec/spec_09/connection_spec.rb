# encoding: utf-8

# connection_spec.rb

require "bunny"

describe Bunny do

  it "should raise an error if the wrong user name or password is used" do
    b = Bunny.new(:user => 'wrong')
    lambda { b.start}.should raise_error(StandardError)
  end

  it "should merge custom settings from AMQP URL with default settings" do
    b = Bunny.new("amqp://tagadab")
    b.host.should eql("tagadab")
  end

  it "should be able to open a TCPSocket with a timeout" do
    b = Bunny.new
    connect_timeout = 5
    lambda {
      Bunny::Timer::timeout(connect_timeout, Qrack::ConnectionTimeout) do
        TCPSocket.new(b.host, b.port)
      end
    }.should_not raise_error(Exception)
  end

  it "should know the default port of a SSL connection" do
    b = Bunny.new(:ssl => true)
    b.port.should eql(5671)
  end

end
