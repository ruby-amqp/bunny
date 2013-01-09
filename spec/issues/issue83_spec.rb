require "spec_helper"

describe Bunny::Channel, "#open" do
  let(:connection) do
    c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed")
    c.start
    c
  end

  after :all do
    connection.close if connection.open?
  end


  it "properly resets channel exception state" do
    ch = connection.create_channel

    begin
      ch.queue("bunny.tests.does.not.exist", :passive => true)
    rescue Bunny::NotFound
      # expected
    end

    # reopen the channel
    ch.open

    # should not raise
    q = ch.queue("bunny.tests.my.queue")
    q.delete
  end
end
