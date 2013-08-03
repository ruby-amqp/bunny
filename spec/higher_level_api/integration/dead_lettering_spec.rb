require "spec_helper"

describe "A message" do
  let(:connection) do
    c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed")
    c.start
    c
  end

  after :each do
    connection.close if connection.open?
  end

  it "is considered to be dead-lettered when it is rejected without requeueing" do
    ch   = connection.create_channel
    x    = ch.fanout("amq.fanout")
    dlx  = ch.fanout("bunny.tests.dlx.exchange")
    q    = ch.queue("", :exclusive => true, :arguments => {"x-dead-letter-exchange" => dlx.name}).bind(x)
    # dead letter queue
    dlq  = ch.queue("", :exclusive => true).bind(dlx)

    x.publish("")
    sleep 0.2

    delivery_info, _, _ = q.pop(:ack => true)
    dlq.message_count.should be_zero
    ch.nack(delivery_info.delivery_tag)

    sleep 0.2
    q.message_count.should be_zero
    dlq.message_count.should == 1

    dlx.delete
  end

  it "is considered to be dead-lettered when it expires" do
    ch   = connection.create_channel
    x    = ch.fanout("amq.fanout")
    dlx  = ch.fanout("bunny.tests.dlx.exchange")
    q    = ch.queue("", :exclusive => true, :arguments => {"x-dead-letter-exchange" => dlx.name, "x-message-ttl" => 100}).bind(x)
    # dead letter queue
    dlq  = ch.queue("", :exclusive => true).bind(dlx)

    x.publish("")
    sleep 0.2

    q.message_count.should be_zero
    dlq.message_count.should == 1

    dlx.delete
  end
end
