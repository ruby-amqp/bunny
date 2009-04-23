# queue_spec.rb

# Assumes that target message broker/server has a user called 'guest' with a password 'guest'
# and that it is running on 'localhost'.

# If this is not the case, please change the 'Bunny.new' call below to include
# the relevant arguments e.g. @b = Bunny.new(:user => 'john', :pass => 'doe', :host => 'foobar')

require File.expand_path(File.join(File.dirname(__FILE__), %w[.. lib bunny]))

describe Bunny do
	
	before(:each) do
    @b = Bunny.new
		@b.start
	end
	
	after(:each) do
		@b.stop
	end

	it "should be able to publish a message" do
		q = @b.queue('test1')
		q.publish('This is a test message')
		q.message_count.should == 1
	end
	
	it "should be able to pop a message complete with header" do
		q = @b.queue('test1')
		msg = q.pop(:header => true)
		msg.should be_an_instance_of Hash
		msg[:header].should be_an_instance_of AMQP::Protocol::Header
		msg[:payload].should == 'This is a test message'
		q.message_count.should == 0
	end

	it "should be able to pop a message and just get the payload" do
		q = @b.queue('test1')
		q.publish('This is another test message')
		msg = q.pop
		msg.should == 'This is another test message'
		q.message_count.should == 0
	end

	it "should be able to be deleted" do
		q = @b.queue('test1')
		q.delete
		@b.queues.has_key?('test1').should be false
	end
	
end