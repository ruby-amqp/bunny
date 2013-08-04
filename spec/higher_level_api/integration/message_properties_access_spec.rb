require "spec_helper"

describe Bunny::Queue, "#subscribe" do
  let(:connection) do
    c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed")
    c.start
    c
  end

  after :each do
    connection.close if connection.open?
  end

  let(:queue_name) { "bunny.basic_consume#{rand}" }

  it "provides delivery handler access to message properties" do
    @now     = Time.now
    metadata = {}
    envelope = {}

    t = Thread.new do
      ch = connection.create_channel
      q = ch.queue(queue_name, :auto_delete => true, :durable => false)
      q.subscribe(:exclusive => true, :ack => false) do |delivery_info, properties, payload|
        metadata = properties
        envelope = delivery_info
      end
    end
    t.abort_on_exception = true
    sleep 0.5

    ch = connection.create_channel
    x  = ch.default_exchange
    x.publish("hello",
              :routing_key => queue_name,
              :app_id      => "bunny.example",
              :priority    => 8,
              :type        => "kinda.checkin",
              # headers table keys can be anything
              :headers     => {
                :coordinates => {
                  :latitude  => 59.35,
                  :longitude => 18.066667
                },
                :time         => @now,
                :participants => 11,
                :venue        => "Stockholm",
                :true_field   => true,
                :false_field  => false,
                :nil_field    => nil,
                :ary_field    => ["one", 2.0, 3, [{"abc" => 123}]]
              },
              :timestamp      => @now.to_i,
              :reply_to       => "a.sender",
              :correlation_id => "r-1",
              :message_id     => "m-1")

    sleep 0.7

    metadata.content_type.should == "application/octet-stream"
    metadata.priority.should     == 8

    time = metadata.headers["time"]
    time.year.should == @now.year
    time.month.should == @now.month
    time.day.should == @now.day
    time.hour.should == @now.hour
    time.min.should == @now.min
    time.sec.should == @now.sec

    metadata.headers["coordinates"]["latitude"].should == 59.35
    metadata.headers["participants"].should == 11
    metadata.headers["venue"].should == "Stockholm"
    metadata.headers["true_field"].should == true
    metadata.headers["false_field"].should == false
    metadata.headers["nil_field"].should be_nil
    metadata.headers["ary_field"].should == ["one", 2.0, 3, [{ "abc" => 123}]]

    metadata.timestamp.should == Time.at(@now.to_i)
    metadata.type.should == "kinda.checkin"
    metadata.reply_to.should == "a.sender"
    metadata.correlation_id.should == "r-1"
    metadata.message_id.should == "m-1"
    metadata.app_id.should == "bunny.example"

    envelope.consumer_tag.should_not be_nil
    envelope.consumer_tag.should_not be_empty
    envelope.should_not be_redelivered
    envelope.delivery_tag.should == 1
    envelope.routing_key.should  == queue_name
    envelope.exchange.should == ""

    ch.close
  end
end
