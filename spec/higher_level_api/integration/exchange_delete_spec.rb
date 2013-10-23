require "spec_helper"

describe Bunny::Exchange, "#delete" do
  let(:connection) do
    c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed")
    c.start
    c
  end

  after :each do
    connection.close if connection.open?
  end


  context "with a name of an existing exchange" do
    it "deletes that exchange" do
      ch = connection.create_channel
      x  = ch.fanout("bunny.tests.exchanges.fanout#{rand}")

      x.delete
      # no exception as of RabbitMQ 3.2. MK.
      x.delete

      ch.exchanges.size.should == 0
    end
  end


  context "with a name of a non-existent exchange" do
    it "DOES NOT rais an exception" do
      ch = connection.create_channel

      # no exception as of RabbitMQ 3.2. MK.
      ch.exchange_delete("sdkhflsdjflskdjflsd#{rand}")
      ch.exchange_delete("sdkhflsdjflskdjflsd#{rand}")
      ch.exchange_delete("sdkhflsdjflskdjflsd#{rand}")
      ch.exchange_delete("sdkhflsdjflskdjflsd#{rand}")
    end
  end

  context "with a name of 'amq.direct'" do
    it "does not delete the exchange" do
      ch = connection.create_channel
      x  = ch.direct('amq.direct')

      x.delete.should == nil
    end
  end

  context "with a name of 'amq.fanout'" do
    it "does not delete the exchange" do
      ch = connection.create_channel
      x  = ch.fanout('amq.fanout')

      x.delete.should == nil
    end
  end

  context "with a name of 'amq.topic'" do
    it "does not delete the exchange" do
      ch = connection.create_channel
      x  = ch.topic('amq.topic')

      x.delete.should == nil
    end
  end

  context "with a name of 'amq.headers'" do
    it "does not delete the exchange" do
      ch = connection.create_channel
      x  = ch.headers('amq.headers')

      x.delete.should == nil
    end
  end

  context "with a name of 'amq.match'" do
    it "does not delete the exchange" do
      ch = connection.create_channel
      x  = ch.headers('amq.match')

      x.delete.should == nil
    end
  end


  describe "#exchange_exists?" do
    context "when a exchange exists" do
      it "returns true" do
        ch = connection.create_channel

        connection.exchange_exists?("amq.fanout").should be_true
        connection.exchange_exists?("amq.direct").should be_true
        connection.exchange_exists?("amq.topic").should be_true
        connection.exchange_exists?("amq.match").should be_true
      end
    end

    context "when a exchange DOES NOT exist" do
      it "returns false" do
        connection.exchange_exists?("suf89u9a4jo3ndnakls##{Time.now.to_i}").should be_false
      end
    end
  end
end
