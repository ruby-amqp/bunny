# exchange_spec.rb

# Assumes that target message broker/server has a user called 'guest' with a password 'guest'
# and that it is running on 'localhost'.

# If this is not the case, please change the 'Bunny.new' call below to include
# the relevant arguments e.g. @b = Bunny.new(:user => 'john', :pass => 'doe', :host => 'foobar')

require File.expand_path(File.join(File.dirname(__FILE__), %w[.. lib bunny]))

describe Exchange do
	
	before(:each) do
    @b = Bunny.new
		@b.start
	end
	
	after(:each) do
		@b.stop
	end
	
	it "should be able to create a default direct exchange" do
		exch = @b.exchange('direct_defaultex')
		exch.should be_an_instance_of Exchange
		exch.name.should == 'direct_defaultex'
		exch.type.should == :direct
		@b.exchanges.has_key?('direct_defaultex').should be true
	end
	
	it "should be able to be instantiated as a direct exchange" do
		exch = @b.exchange('direct_exchange', :type => :direct)
		exch.should be_an_instance_of Exchange
		exch.name.should == 'direct_exchange'
		exch.type.should == :direct
		@b.exchanges.has_key?('direct_exchange').should be true
	end
	
	it "should be able to be instantiated as a topic exchange" do
		exch = @b.exchange('topic_exchange', :type => :topic)
		exch.should be_an_instance_of Exchange
		exch.name.should == 'topic_exchange'
		exch.type.should == :topic
		@b.exchanges.has_key?('topic_exchange').should be true
	end
	
	it "should be able to be instantiated as a fanout exchange" do
		exch = @b.exchange('fanout_exchange', :type => :fanout)
		exch.should be_an_instance_of Exchange
		exch.name.should == 'fanout_exchange'
		exch.type.should == :fanout
		@b.exchanges.has_key?('fanout_exchange').should be true
	end
	
	it "should be able to be instantiated as a headers exchange" do
		exch = @b.exchange('head_exchange', :type => :headers)
		exch.should be_an_instance_of Exchange
		exch.name.should == 'head_exchange'
		exch.type.should == :headers
		@b.exchanges.has_key?('head_exchange').should be true
	end
	
	it "should be able to publish a message" do
		exch = @b.exchange('direct_exchange')
		exch.publish('This is a published message')
	end
	
	it "should be able to be deleted" do
		exch = @b.exchange('direct_exchange')
		exch.delete
		@b.exchanges.has_key?('direct_exchange').should be false
	end
	
end