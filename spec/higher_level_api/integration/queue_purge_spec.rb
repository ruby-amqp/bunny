require "spec_helper"

describe Bunny::Queue do
  let(:connection) do
    c = Bunny.new(username: "bunny_gem", password: "bunny_password", vhost: "bunny_testbed")
    c.start
    c
  end

  after :each do
    connection.close
  end


  it "can be purged" do
    ch = connection.create_channel

    q  = ch.queue("", exclusive: true)
    x  = ch.default_exchange

    x.publish("xyzzy", routing_key: q.name)
    sleep(0.5)

    expect(q.message_count).to eq 1
    q.purge
    expect(q.message_count).to eq 0

    ch.close
  end
end
