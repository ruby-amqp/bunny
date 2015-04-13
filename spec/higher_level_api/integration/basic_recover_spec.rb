require "spec_helper"

describe Bunny::Channel, "#recover" do
  let(:connection) do
    c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed")
    c.start
    c
  end

  subject do
    connection.create_channel
  end

  it "is supported" do
    expect(subject.recover(true)).to be_instance_of(AMQ::Protocol::Basic::RecoverOk)
    expect(subject.recover(true)).to be_instance_of(AMQ::Protocol::Basic::RecoverOk)
  end
end
