require "spec_helper"

describe Bunny::Exception do
  let(:connection) do
    c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed")
    c.start
    c
  end

  after :all do
    connection.close
  end

  context "when deleting a non-existent queue" do
    it "raises an Bunny::Exception" do
      ch = connection.create_channel

      expect {
        ch.queue_delete("sdkhflsdjflskdjflsd#{rand}")
      }.to raise_error(Bunny::Exception)
    end

    it "raises an Bunny::NotFound" do
      ch = connection.create_channel

      expect {
        ch.queue_delete("sdkhflsdjflskdjflsd#{rand}")
      }.to raise_error(Bunny::NotFound)
    end
  end
end
