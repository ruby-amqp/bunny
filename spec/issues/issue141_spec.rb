require "spec_helper"

describe "Registering 2nd exclusive consumer on queue" do
    before :all do
    @connection = Bunny.new(:user => "bunny_gem", password:  "bunny_password", :vhost => "bunny_testbed")
    @connection.start
  end

  after :each do
    @connection.close if @connection.open?
  end


  it "raises a meaningful exception" do
    xs  = []

    ch1 = @connection.create_channel
    ch2 = @connection.create_channel
    q1  = ch1.queue("", :auto_delete => true)
    q2  = ch2.queue(q1.name, :auto_delete => true, :passive => true)

    c1  = q1.subscribe(exclusive: true) do |_, _, payload|
      xs << payload
    end
    sleep 0.1

    expect do
      q2.subscribe(exclusive: true) do |_, _, _|
      end
    end.to raise_error(Bunny::AccessRefused)

    expect(ch1).to be_open
    expect(ch2).to be_closed

    q1.publish("abc")
    sleep 0.1

    # verify that the first consumer is fine
    expect(xs).to eq ["abc"]

    q1.delete
  end
end
