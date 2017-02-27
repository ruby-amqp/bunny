require "spec_helper"

describe Bunny::Exchange do
  let(:connection) do
    c = Bunny.new(username: "bunny_gem", password: "bunny_password", vhost: "bunny_testbed")
    c.start
    c
  end

  after :each do
    connection.close if connection.open?
  end

  it "unbinds two existing exchanges" do
    ch          = connection.create_channel

    source      = ch.fanout("bunny.exchanges.source#{rand}")
    destination = ch.fanout("bunny.exchanges.destination#{rand}")

    queue       = ch.queue("", exclusive: true)
    queue.bind(destination)

    destination.bind(source)
    source.publish("")
    sleep 0.5

    expect(queue.message_count).to eq 1
    queue.pop(manual_ack: true)

    destination.unbind(source)
    source.publish("")
    sleep 0.5

    expect(queue.message_count).to eq 0

    source.delete
    destination.delete
    ch.close
  end
end
