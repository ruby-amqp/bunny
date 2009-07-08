# consumer.rb

# N.B. To be used in conjunction with simple_publisher.rb

# Assumes that target message broker/server has a user called 'guest' with a password 'guest'
# and that it is running on 'localhost'.

# If this is not the case, please change the 'Bunny.new' call below to include
# the relevant arguments e.g. b = Bunny.new(:user => 'john', :pass => 'doe', :host => 'foobar')

# How this example works
#=======================
#
# Open up two console windows start this program in one of them by typing -
#
# ruby simple_consumer.rb
#
# Then switch to the other console window and type -
#
# ruby simple_publisher.rb
#
# A message will be printed out by the simple_consumer and it will wait for the next message
#
# Run simple_publisher 3 more times. After the last run simple_consumer will stop.

$:.unshift File.dirname(__FILE__) + '/../lib'

require 'bunny'

b = Bunny.new(:logging => true, :spec => '09')

# start a communication session with the amqp server
b.start

# create/get queue
q = b.queue('po_box')

# create/get exchange
exch = b.exchange('sorting_room')

# bind queue to exchange
q.bind(exch, :key => 'fred')

# initialize counter
i = 1

# subscribe to queue
q.subscribe(:consumer_tag => 'testtag1') do |msg|
	puts i.to_s + ': ' + msg
	i+=1
	q.unsubscribe(:consumer_tag => 'testtag1') if i == 5
end

# close the connection
b.stop