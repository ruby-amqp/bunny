# About Bunny

Bunny is a synchronous RabbitMQ client that focuses on ease of use.


## Supported Ruby Versions

It supports Ruby 1.9.3, 1.9.2, 1.8.7, Rubinius 2 and JRuby.


## Supported RabbitMQ Versions

Bunny versions `< 0.7.x` support RabbitMQ 1.x and 2.x. Bunny `0.8.x` and later versions only
supports RabbitMQ 2.x.


## Important: Bunny is about to undergo a lot of internal changes

Bunny is a very old library with **a lot** of missing functionality. It also implements an older version of the spec
and may or may not work with future RabbitMQ versions. As such, Bunny is about to undergo serious internal changes.
We will make our best to keep them as backwards compatible as possible but within reason.

See [this announcement](https://groups.google.com/forum/?fromgroups#!topic/ruby-amqp/crNVGEuHm68) to learn more.

In the meantime, consider using [Hot Bunnies](http://github.com/ruby-amqp/hot_bunnies) (JRuby-only) or "amqp gem":http://rubyamqp.info instead.


## Quick Start for Bunny 0.7.x and 0.8.x

``` ruby
require "bunny"

b = Bunny.new(:logging => true)

# start a communication session with the amqp server
b.start

# declare a queue
q = b.queue("test1")

# declare default direct exchange which is bound to all queues
e = b.exchange("")

# publish a message to the exchange which then gets routed to the queue
e.publish("Hello, everybody!", :key => 'test1')

# get message from the queue
msg = q.pop[:payload]

puts "This is the message: " + msg + "\n\n"

# close the connection
b.stop
```

... or just:

```
require "bunny"

# Create a direct queue named "my_testq"
Bunny.run { |c| c.queue("my_testq") }
```

## Community & Getting Help

Please use [Ruby RabbitMQ clients Google Group](http://groups.google.com/group/ruby-amqp) for any questions you may
have.

For news and updates, [follow @rubyamqp](http://twitter.com/rubyamqp) on Twitter.



## Other Resources

* [AMQP 0.9.1 model explained](): introductory explanation of the AMQP v0.9.1 specification with particular reference to RabbitMQ.


## Links

* [Source code](http://github.com/ruby-amqp/bunny)
* [Blog](http://bunnyamqp.wordpress.com)
