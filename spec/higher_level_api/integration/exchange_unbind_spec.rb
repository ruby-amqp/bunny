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
    sx_name     = "bunny.exchanges.source#{rand}"
    dx_name     = "bunny.exchanges.destination#{rand}"

    ch.exchange_delete(sx_name)
    ch.exchange_delete(dx_name)

    source      = ch.fanout(sx_name)
    destination = ch.fanout(dx_name)

    queue       = ch.queue("", exclusive: true)
    queue.bind(destination)

    destination.bind(source)
    source.publish("")
    sleep 0.5

    expect(queue.message_count).to eq 1
    queue.purge

    destination.unbind(source)
    sleep 0.5

    3.times do
      source.publish("")
    end
    sleep 0.5

    expect(queue.message_count).to eq 0

    source.delete
    destination.delete
    ch.close
  end
end
