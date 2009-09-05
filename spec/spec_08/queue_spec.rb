# queue_spec.rb

# Assumes that target message broker/server has a user called 'guest' with a password 'guest'
# and that it is running on 'localhost'.

# If this is not the case, please change the 'Bunny.new' call below to include
# the relevant arguments e.g. @b = Bunny.new(:user => 'john', :pass => 'doe', :host => 'foobar')

require File.expand_path(File.join(File.dirname(__FILE__), %w[.. .. lib bunny]))

describe Bunny do
	
	before(:each) do
    @b = Bunny.new
		@b.start
	end
	
	it "should ignore the :nowait option when instantiated" do
		q = @b.queue('test0', :nowait => true)
	end
	
	it "should ignore the :nowait option when binding to an exchange" do
		exch = @b.exchange('direct_exch')
		q = @b.queue('test0')
		q.bind(exch, :nowait => true).should == :bind_ok
	end
	
	it "should be able to bind to an exchange" do
		exch = @b.exchange('direct_exch')
		q = @b.queue('test1')
		q.bind(exch).should == :bind_ok
	end
	
	it "should ignore the :nowait option when unbinding from an exchange" do
		exch = @b.exchange('direct_exch')
		q = @b.queue('test0')
		q.unbind(exch, :nowait => true).should == :unbind_ok
	end
	
	it "should be able to unbind from an exchange" do
		exch = @b.exchange('direct_exch')
		q = @b.queue('test1')
		q.unbind(exch).should == :unbind_ok
	end

	it "should be able to publish a message" do
		q = @b.queue('test1')
		q.publish('This is a test message')
		q.message_count.should == 1
	end
	
	it "should be able to pop a message complete with header and delivery details" do
		q = @b.queue('test1')
		msg = q.pop(:header => true)
		msg.should be_an_instance_of(Hash)
		msg[:header].should be_an_instance_of(Bunny::Protocol::Header)
		msg[:payload].should == 'This is a test message'
		msg[:delivery_details].should be_an_instance_of(Hash)
		q.message_count.should == 0
	end

	it "should be able to pop a message and just get the payload" do
		q = @b.queue('test1')
		q.publish('This is another test message')
		msg = q.pop
		msg.should == 'This is another test message'
		q.message_count.should == 0
	end
	
	it "should be able to pop a message where body length exceeds max frame size" do
		q = @b.queue('test1')
		lg_msg = 'z' * 142000
		q.publish(lg_msg)
		msg = q.pop
		msg.should == lg_msg
	end
	
	it "should be able to be purged to remove all of its messages" do
		q = @b.queue('test1')
		5.times {q.publish('This is another test message')}
		q.message_count.should == 5
		q.purge
		q.message_count.should == 0
	end
	
	it "should return an empty message when popping an empty queue" do
		q = @b.queue('test1')
		q.publish('This is another test message')
		q.pop
		msg = q.pop
		msg.should == :queue_empty
	end
	
	it "should stop subscription without processing messages if max specified is 0" do
		q = @b.queue('test1')
		5.times {q.publish('Yet another test message')}
		q.message_count.should == 5
		q.subscribe(:message_max => 0){|msg| x = 1}
		q.message_count.should == 5
		q.unsubscribe.should == :unsubscribe_ok
		q.purge.should == :purge_ok
	end
	
	it "should stop subscription after processing number of messages specified > 0" do
		q = @b.queue('test1')
		5.times {q.publish('Yet another test message')}
		q.message_count.should == 5
		q.subscribe(:message_max => 5){|msg| x = 1}
		q.unsubscribe.should == :unsubscribe_ok
	end

	it "should be able to be deleted" do
		q = @b.queue('test1')
		res = q.delete
		res.should == :delete_ok
		@b.queues.has_key?('test1').should be(false)
	end
	
	it "should ignore the :nowait option when deleted" do
		q = @b.queue('test0')
		q.delete(:nowait => true)
	end

  it "should support server named queues" do
    q = @b.queue
    q.name.should_not == nil

    @b.queue(q.name).should == q
    q.delete
  end
	
end
