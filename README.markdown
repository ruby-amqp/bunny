# README

## About

*bunny* is an AMQP client, written in Ruby, that is intended to allow you to interact with AMQP-compliant message brokers/servers such as RabbitMQ in a synchronous fashion.

You can use *bunny* to -

* Create and delete exchanges
* Create and delete queues
* Publish and consume messages
 
*bunny* is being tested with RabbitMQ version 1.5.4 and version 0-8 of the AMQP specification.

There is a Google Group for discussing bunny - [bunny-amqp](http://groups.google.com/group/bunny-amqp)
 
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

## Acknowledgements

This project has borrowed heavily from the following two projects and owes their respective creators and collaborators a whole lot of gratitude:

1. **amqp** by *tmm1* [http://github.com/tmm1/amqp/tree/master](http://github.com/tmm1/amqp/tree/master)
2. **carrot** by *famoseagle* [http://github.com/famoseagle/carrot/tree/master](http://github.com/famoseagle/carrot/tree/master)

## LICENSE

Copyright (c) 2009 Chris Duncan; Published under The MIT License, see License
