require "spec_helper"

describe Bunny::Exchange do
  let(:connection) do
    c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed")
    c.start
    c
  end

  after :all do
    connection.close if connection.open?
  end

  it "binds two existing exchanges" do
    ch          = connection.create_channel

    source      = ch.fanout("bunny.exchanges.source", :auto_delete => true)
    destination = ch.fanout("bunny.exchanges.destination", :auto_delete => true)

    queue       = ch.queue("", :exclusive => true)
    queue.bind(destination)

    destination.bind(source)
    source.publish("")
    sleep 0.5

    queue.message_count.should be > 0

    ch.close
  end
end
