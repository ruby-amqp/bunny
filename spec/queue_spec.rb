# queue_spec.rb

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

	it "should be able to pop a message" do
		q = @b.queue('test1')
		msg = q.pop
		msg.should == 'This is a test message'
		q.message_count.should == 0
	end

	it "should be able to be deleted" do
		q = @b.queue('test1')
		q.delete
		@b.queues.has_key?('test1').should be false
	end
	
end