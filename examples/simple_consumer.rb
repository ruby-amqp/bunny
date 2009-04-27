# consumer.rb

# N.B. To be used in conjunction with publisher.rb - RUN THIS BEFORE simple_publisher.rb

# Assumes that target message broker/server has a user called 'guest' with a password 'guest'
# and that it is running on 'localhost'.

# If this is not the case, please change the 'Bunny.new' call below to include
# the relevant arguments e.g. b = Bunny.new(:user => 'john', :pass => 'doe', :host => 'foobar')

$:.unshift File.dirname(__FILE__) + '/../lib'

require 'bunny'

b = Bunny.new(:logging => true)

# start a communication session with the amqp server
b.start

# create/get queue
q = b.queue('po_box')

# create/get exchange
exch = b.exchange('sorting_room')

# bind queue to exchange
q.bind(exch, :key => 'fred')

# subscribe to queue
msg = q.subscribe(:consumer_tag => 'testtag1')

# output received message
puts msg

# close the connection
b.stop