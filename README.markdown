# Bunny: A synchronous Ruby AMQP client

Google Group: [bunny-amqp](http://groups.google.com/group/bunny-amqp)

## Announcements

**IMPORTANT**

The Exchange#initialize method arguments have changed as of version 0.0.7

You now create an exchange like this -

    b = Bunny.new
    exch = b.exchange('my_exchange', :type => :fanout)

If you do not specify a :type option then a default of :direct is used.

The old way was -

    b = Bunny.new
    exch = b.exchange(:fanout, 'my_exchange')

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

## Bunny methods

These are the Bunny methods that you will probably want to use -

### Create a Bunny instance
Bunny#new({_options_})

### Start a communication session with the target server
Bunny#start

### Stop a communication session with the target server
Bunny#stop

### Create a Queue
Bunny#queue(_**name**_, {_options_})

### Create an Exchange
Bunny#exchange(_**name**_, {_options_})

### Return connection status ('CONNECTED' or 'NOT CONNECTED')
Bunny#status               

### Publish a message to an exchange
Exchange#publish(_**data**_, {_options_})

### Delete an exchange from the target server
Exchange#delete({_options_})

### Bind a queue to an exchange
Queue#bind(_**exchange**_, {_options_})

### Unbind a queue from an exchange
Queue#unbind(_**exchange**_, {_options_})

### Publish a message to a queue
Queue#publish(_**data**_, {_options_})

### Pop a message off of a queue
Queue#pop({_options_})

### Return queue message count
Queue#message_count

### Return queue consumer count
Queue#consumer_count

### Return queue status (array of message count and consumer_count)
Queue#status

### Send an acknowledge message to the server
Queue#ack

### Delete a queue from the target server
Queue#delete({_options_})

## Acknowledgements

This project has borrowed heavily from the following two projects and owes their respective creators and collaborators a whole lot of gratitude:

1. **amqp** by *tmm1* [http://github.com/tmm1/amqp/tree/master](http://github.com/tmm1/amqp/tree/master)
2. **carrot** by *famoseagle* [http://github.com/famoseagle/carrot/tree/master](http://github.com/famoseagle/carrot/tree/master)

## LICENSE

Copyright (c) 2009 Chris Duncan; Published under The MIT License, see License
