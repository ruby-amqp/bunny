# queue_spec.rb

# Assumes that target message broker/server has a user called 'guest' with a password 'guest'
# and that it is running on 'localhost'.

# If this is not the case, please change the 'Bunny.new' call below to include
# the relevant arguments e.g. @b = Bunny.new(:user => 'john', :pass => 'doe', :host => 'foobar')

require File.expand_path(File.join(File.dirname(__FILE__), %w[.. lib bunny]))

describe Bunny::Queue do
	
	before(:each) do
    @b = Bunny::Client.new
		@b.start
	end
	
	it "should ignore the :nowait option when instantiated" do
		q = @b.queue('test0', :nowait => true)
	end
	
	it "should ignore the :nowait option when binding to an exchange" do
		exch = @b.exchange('direct_exch')
		q = @b.queue('test0')
		q.bind(exch, :nowait => true).should == 'BIND SUCCEEDED'
	end
	
	it "should be able to bind to an exchange" do
		exch = @b.exchange('direct_exch')
		q = @b.queue('test1')
		q.bind(exch).should == 'BIND SUCCEEDED'
	end
	
	it "should ignore the :nowait option when unbinding from an exchange" do
		exch = @b.exchange('direct_exch')
		q = @b.queue('test0')
		q.unbind(exch, :nowait => true).should == 'UNBIND SUCCEEDED'
	end
	
	it "should be able to unbind from an exchange" do
		exch = @b.exchange('direct_exch')
		q = @b.queue('test1')
		q.unbind(exch).should == 'UNBIND SUCCEEDED'
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
		msg[:header].should be_an_instance_of Protocol::Header
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
	
	it "should return an empty message when popping an empty queue" do
		q = @b.queue('test1')
		q.publish('This is another test message')
		q.pop
		msg = q.pop
		msg.should == 'QUEUE EMPTY'
	end

	it "should be able to be deleted" do
		q = @b.queue('test1')
		res = q.delete
		res.should == 'QUEUE DELETED'
		@b.queues.has_key?('test1').should be false
	end
	
	it "should ignore the :nowait option when deleted" do
		q = @b.queue('test0')
		q.delete(:nowait => true)
	end
	
end