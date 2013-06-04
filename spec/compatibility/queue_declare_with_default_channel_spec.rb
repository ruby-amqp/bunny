require "spec_helper"

describe Bunny::Session do
  let(:connection) do
    c = Bunny.new
    c.start
    c
  end

  after :all do
    connection.close if connection.open?
  end

  it "proxies #queue to the pre-opened channel for backwards compatibility" do
    q = connection.queue("", :exclusive => true)
    q.name.should =~ /^amq.gen/
  end

  it "proxies #fanout to the pre-opened channel for backwards compatibility" do
    x = connection.fanout("amq.fanout")
    x.name.should == "amq.fanout"
  end

  it "proxies #topic to the pre-opened channel for backwards compatibility" do
    x = connection.topic("amq.topic")
    x.name.should == "amq.topic"
  end

  it "proxies #direct to the pre-opened channel for backwards compatibility" do
    x = connection.topic("amq.direct")
    x.name.should == "amq.direct"
  end
end
