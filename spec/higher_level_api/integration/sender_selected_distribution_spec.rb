require "spec_helper"

describe "Sender-selected distribution" do
  let(:connection) do
    c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed")
    c.start
    c
  end

  after :all do
    connection.close if connection.open?
  end

  it "lets publishers specify additional routing keys using CC and BCC headers" do
    ch   = connection.create_channel
    x    = ch.direct("bunny.tests.ssd.exchange")
    q1   = ch.queue("", :exclusive => true).bind(x, :routing_key => "one")
    q2   = ch.queue("", :exclusive => true).bind(x, :routing_key => "two")
    q3   = ch.queue("", :exclusive => true).bind(x, :routing_key => "three")
    q4   = ch.queue("", :exclusive => true).bind(x, :routing_key => "four")

    n    = 10
    n.times do |i|
      x.publish("Message #{i}", :routing_key => "one", :headers => {"CC" => ["two", "three"]})
    end
    
    sleep 0.5

    q1.message_count.should == n
    q2.message_count.should == n
    q3.message_count.should == n
    q4.message_count.should be_zero

    x.delete
  end
end
