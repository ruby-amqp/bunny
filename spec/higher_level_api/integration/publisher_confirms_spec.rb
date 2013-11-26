require "spec_helper"

describe Bunny::Channel do
  let(:connection) do
    c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed", :continuation_timeout => 10000)
    c.start
    c
  end

  after :each do
    connection.close if connection.open?
  end

  let(:n) { 200 }

  context "when publishing with confirms enabled" do
    it "increments delivery index" do
      ch = connection.create_channel
      ch.should_not be_using_publisher_confirmations

      ch.confirm_select
      ch.should be_using_publisher_confirmations

      q  = ch.queue("", :exclusive => true)
      x  = ch.default_exchange

      n.times do
        x.publish("xyzzy", :routing_key => q.name)
      end

      ch.next_publish_seq_no.should == n + 1
      ch.wait_for_confirms.should be_true
      sleep 0.25

      q.message_count.should == n
      q.purge

      ch.close
    end
  end


  context "with a single-threaded connection" do
    let(:connection) do
      c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed", :continuation_timeout => 10000, :threaded => false)
      c.start
      c
    end


    context "when publishing with confirms enabled" do
      it "increments delivery index" do
        ch = connection.create_channel
        ch.should_not be_using_publisher_confirmations

        ch.confirm_select
        ch.should be_using_publisher_confirmations

        q  = ch.queue("", :exclusive => true)
        x  = ch.default_exchange

        n.times do
          x.publish("xyzzy", :routing_key => q.name)
        end

        ch.next_publish_seq_no.should == n + 1
        ch.wait_for_confirms.should be_true
        sleep 0.25

        q.message_count.should == n
        q.purge

        ch.close
      end
    end
  end
end
