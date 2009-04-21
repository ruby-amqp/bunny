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
q = b.queue('test1')

# create a direct exchange
exch = b.exchange(:direct, 'test_ex')

# bind the queue to the exchange
q.bind(exch)

# publish a message to the exchange
exch.publish('Hello everybody!')

# get message from the queue
msg = q.pop

puts 'This is the message: ' + msg + "\n\n"