# Bunny: A synchronous Ruby AMQP client

Google Group: [bunny-amqp](http://groups.google.com/group/bunny-amqp)

## About

*Bunny* is an [AMQP](http://www.amqp.org) (Advanced Message Queuing Protocol) client, written in Ruby, that is intended to allow you to interact with AMQP-compliant message brokers/servers such as [RabbitMQ](http://www.rabbitmq.com) in a synchronous fashion.

You can use *Bunny* to -

* Create and delete exchanges
* Create and delete queues
* Publish and consume messages
 
*Bunny* is known to work with RabbitMQ version 1.5.4 and version 0-8 of the AMQP specification. If you want to try to use it with other AMQP message brokers/servers please let me know how you get on.
 
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

    # publish a message to the queue
    q.publish('Hello everybody!')

    # get message from the queue
    msg = q.pop

    puts 'This is the message: ' + msg + "\n\n"

    # close the connection
    b.close

## Acknowledgements

This project has borrowed heavily from the following two projects and owes their respective creators and collaborators a whole lot of gratitude:

1. **amqp** by *tmm1* [http://github.com/tmm1/amqp/tree/master](http://github.com/tmm1/amqp/tree/master)
2. **carrot** by *famoseagle* [http://github.com/famoseagle/carrot/tree/master](http://github.com/famoseagle/carrot/tree/master)

## LICENSE

Copyright (c) 2009 Chris Duncan; Published under The MIT License, see License
