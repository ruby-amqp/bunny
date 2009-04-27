# Bunny: A synchronous Ruby AMQP client

Google Group: [http://groups.google.com/group/bunny-amqp](http://groups.google.com/group/bunny-amqp)

Mailing List: [http://rubyforge.org/mailman/listinfo/bunny-amqp-devel](http://rubyforge.org/mailman/listinfo/bunny-amqp-devel)

Rubyforge: [http://rubyforge.org/projects/bunny-amqp](http://rubyforge.org/projects/bunny-amqp)

Twitter: [http://twitter.com/bunny_amqp](https://twitter.com/bunny_amqp)

## Announcements

Bunny v0.1.1 has been released. It contains the following changes -

*  Queue#delete method returns ‘QUEUE DELETED’, Exchange#delete method returns ‘EXCHANGE DELETED’, Queue#bind returns ‘BIND SUCCEEDED’, Queue#unbind returns ‘UNBIND SUCCEEDED’
* Queue#subscribe method available (see example bunny/examples/simple_consumer.rb)
* Queue#status now returns a hash {:message_count, :consumer_count}
* Queue#ack works after a Queue#subscribe or Queue#pop if :ack => true was specified

## About

*Bunny* is an [AMQP](http://www.amqp.org) (Advanced Message Queuing Protocol) client, written in Ruby, that is intended to allow you to interact with AMQP-compliant message brokers/servers such as [RabbitMQ](http://www.rabbitmq.com) in a synchronous fashion.

It is based on a great deal of fabulous code from [amqp](http://github.com/tmm1/amqp) by Aman Gupta and [Carrot](http://github.com/famoseagle/carrot) by Amos Elliston.

You can use *Bunny* to -

* Create and delete exchanges
* Create and delete queues
* Publish and consume messages
 
*Bunny* is known to work with RabbitMQ version 1.5.4 and version 0-8 of the AMQP specification. If you want to try to use it with other AMQP message brokers/servers please let me know how you get on.
 
## Quick Start

    require 'bunny'

    b = Bunny.new(:logging => true)

    # start a communication session with the amqp server
    b.start

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

### Return queue status (hash {:message count, :consumer_count})
Queue#status

### Delete a queue from the target server
Queue#delete({_options_})

### Acknowledge receipt of a message
Queue#ack

## Acknowledgements

This project has borrowed heavily from the following two projects and owes their respective creators and collaborators a whole lot of gratitude:

1. **amqp** by *tmm1* [http://github.com/tmm1/amqp/tree/master](http://github.com/tmm1/amqp/tree/master)
2. **carrot** by *famoseagle* [http://github.com/famoseagle/carrot/tree/master](http://github.com/famoseagle/carrot/tree/master)

## LICENSE

Copyright (c) 2009 Chris Duncan; Published under The MIT License, see License
