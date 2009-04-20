# bunny_spec.rb

require File.expand_path(File.join(File.dirname(__FILE__), %w[.. lib bunny]))

describe Bunny do
	
	before(:each) do
    @b = Bunny.new
		@b.start
	end
	
  it "should connect to an AMQP server" do
    @b.status.should == 'CONNECTED'
  end

	it "should be able to create a queue" do
		q = @b.queue('test1')
		q.should be_an_instance_of Queue
		q.name.should == 'test1'
  end

end