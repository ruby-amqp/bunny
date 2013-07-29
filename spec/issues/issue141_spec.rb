require "spec_helper"

describe "Registering 2nd exclusive consumer on queue" do
  let(:connection) do
    c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed")
    c.start
    c
  end

  after :each do
    connection.close if connection.open?
  end


  it "raises a meaningful exception" do
    xs  = []

    ch1 = connection.create_channel
    ch2 = connection.create_channel
    q1  = ch1.queue("", :auto_delete => true)
    q2  = ch2.queue(q1.name, :auto_delete => true, :passive => true)

    c1  = q1.subscribe(:exclusive => true) do |_, _, payload|
      xs << payload
    end
    sleep 0.1

    lambda do
      q2.subscribe(:exclusive => true) do |_, _, _|
      end
    end.should raise_error(Bunny::AccessRefused)

    ch1.should be_open
    ch2.should be_closed

    q1.publish("abc")
    sleep 0.1

    # verify that the first consumer is fine
    xs.should == ["abc"]

    q1.delete
  end
end
