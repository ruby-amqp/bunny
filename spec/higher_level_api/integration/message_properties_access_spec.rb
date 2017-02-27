require "spec_helper"

describe Bunny::Queue, "#subscribe" do
  let(:connection) do
    c = Bunny.new(username: "bunny_gem", password: "bunny_password", vhost: "bunny_testbed")
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
      q = ch.queue(queue_name, auto_delete: true, durable: false)
      q.subscribe(exclusive: true, manual_ack: false) do |delivery_info, properties, payload|
        metadata = properties
        envelope = delivery_info
      end
    end
    t.abort_on_exception = true
    sleep 0.5

    ch = connection.create_channel
    x  = ch.default_exchange
    x.publish("hello",
              routing_key: queue_name,
              app_id: "bunny.example",
              priority: 8,
              type: "kinda.checkin",
              # headers table keys can be anything
              headers: {
                coordinates: {
                  latitude: 59.35,
                  longitude: 18.066667
                },
                time: @now,
                participants: 11,
                venue: "Stockholm",
                true_field: true,
                false_field: false,
                nil_field: nil,
                ary_field: ["one", 2.0, 3, [{"abc" => 123}]]
              },
              timestamp: @now.to_i,
              reply_to: "a.sender",
              correlation_id: "r-1",
              message_id: "m-1")

    sleep 0.7

    expect(metadata.content_type).to eq "application/octet-stream"
    expect(metadata.priority).to     eq 8

    time = metadata.headers["time"]
    expect(time.year).to eq @now.year
    expect(time.month).to eq @now.month
    expect(time.day).to eq @now.day
    expect(time.hour).to eq @now.hour
    expect(time.min).to eq @now.min
    expect(time.sec).to eq @now.sec

    expect(metadata.headers["coordinates"]["latitude"]).to eq 59.35
    expect(metadata.headers["participants"]).to eq 11
    expect(metadata.headers["venue"]).to eq "Stockholm"
    expect(metadata.headers["true_field"]).to eq true
    expect(metadata.headers["false_field"]).to eq false
    expect(metadata.headers["nil_field"]).to be_nil
    expect(metadata.headers["ary_field"]).to eq ["one", 2.0, 3, [{ "abc" => 123}]]

    expect(metadata.timestamp).to eq Time.at(@now.to_i)
    expect(metadata.type).to eq "kinda.checkin"
    expect(metadata.reply_to).to eq "a.sender"
    expect(metadata.correlation_id).to eq "r-1"
    expect(metadata.message_id).to eq "m-1"
    expect(metadata.app_id).to eq "bunny.example"

    expect(envelope.consumer_tag).not_to be_nil
    expect(envelope.consumer_tag).not_to be_empty
    expect(envelope).not_to be_redelivered
    expect(envelope.delivery_tag).to eq 1
    expect(envelope.routing_key).to  eq queue_name
    expect(envelope.exchange).to eq ""

    ch.close
  end
end
