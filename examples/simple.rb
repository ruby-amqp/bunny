$:.unshift File.dirname(__FILE__) + '/../lib'

require 'bunny'

b = Bunny.new(:logging => true)

# start a communication session with the amqp server
begin
	b.start
rescue Exception => e
	puts 'ERROR - Could not start a session: ' + e
	exit
end

# declare a queue
q = Queue.new(b.client, 'test1')

# create a direct exchange
exchange = Exchange.new(b.client, :direct, 'test_ex')

# bind the queue to the exchange
q.bind(exchange)

# publish a message to the exchange
exchange.publish('Hello everybody!')

# get message from the queue
msg = q.pop

puts 'This is the message: ' + msg + "\n\n"