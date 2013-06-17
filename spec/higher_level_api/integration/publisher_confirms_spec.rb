require "spec_helper"

describe Bunny::Channel do
  let(:connection) do
    c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed")
    c.start
    c
  end

  after :all do
    connection.close if connection.open?
  end


  context "when publishing with confirms enabled" do
    it "increments delivery index" do
      ch = connection.create_channel
      ch.should_not be_using_publisher_confirmations

      ch.confirm_select
      ch.should be_using_publisher_confirmations

      q  = ch.queue("", :exclusive => true)
      x  = ch.default_exchange

      500.times do
        x.publish("xyzzy", :routing_key => q.name)
      end

      ch.next_publish_seq_no.should == 501
      ch.wait_for_confirms.should be_true
      sleep 0.25

      q.message_count.should == 500
      q.purge

      ch.close
    end
  end
end
