# bunny README

This project was started to enable me to interact with RabbitMQ using Ruby. It has borrowed heavily from two projects:
 
1. **amqp** by *tmm1* (http://github.com/tmm1/amqp/tree/master)
2. **carrot** by *famoseagle* (http://github.com/famoseagle/carrot/tree/master)
 
I will be creating tests, examples and generally tinkering, so please bear with me.
 
## Quick Start

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

## LICENSE

Copyright (c) 2009 Chris Duncan; Published under The MIT License, see License
