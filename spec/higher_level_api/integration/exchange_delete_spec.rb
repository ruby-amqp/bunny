require "spec_helper"

describe Bunny::Exchange, "#delete" do
  let(:connection) do
    c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed")
    c.start
    c
  end

  after :all do
    connection.close if connection.open?
  end


  context "with a name of an existing exchange" do
    it "deletes that queue" do
      ch = connection.create_channel
      x  = ch.fanout("bunny.tests.exchanges.fanout#{rand}")

      x.delete
      expect {
        x.delete
      }.to raise_error(Bunny::NotFound)
    end
  end


  context "with a name of an existing exchange" do
    it "raises an exception" do
      ch = connection.create_channel

      expect {
        ch.exchange_delete("sdkhflsdjflskdjflsd#{rand}")
      }.to raise_error(Bunny::NotFound)
    end
  end
end
