# About Bunny

Bunny is a synchronous RabbitMQ client that focuses on ease of use. With the next
0.9 release (currently in master), it is feature complete, supports all RabbitMQ 3.0
features and is free of many limitations of earlier versions.


## Supported Ruby Versions

Bunny 0.9 and more recent versions support Ruby 1.9.3, 1.9.2, JRuby 1.7, Rubinius 2.0 and 1.8.7.


## Supported RabbitMQ Versions

Bunny `0.8.x` and later versions only support RabbitMQ 2.x and 3.x.

Bunny versions `0.7.x` and earlier support RabbitMQ 1.x and 2.x. 


## Changes in Bunny 0.9

Bunny is a very old library with **a lot** of missing functionality. It also implements an older version of the spec
and may or may not work with future RabbitMQ versions. As such, Bunny needed serious internal changes.
We (the maintainers) make our best to keep the new version as backwards compatible as possible but within reason.

See [this announcement](https://groups.google.com/forum/?fromgroups#!topic/ruby-amqp/crNVGEuHm68) to learn more.


## Installation & Bundler Dependency

To install Bunny 0.9.x with RubyGems:

```
gem install bunny --pre
```

To use Bunny 0.9.x in a project managed with Bundler:

``` ruby
gem "bunny", ">= 0.9.0.pre3" # optionally: , :git => "git://github.com/ruby-amqp/bunny.git", :branch => "master"
```


## Quick Start for Bunny 0.9.x

Below is a small snippet that demonstrates how to publish
and synchronously consume ("pull API") messages with Bunny 0.9.

For a 15 minute tutorial using more practical examples, see [Getting Started with RabbitMQ and Ruby using Bunny](http://rubybunny.info/articles/getting_started.html).

``` ruby
require "bunny"

# Start a communication session with RabbitMQ
conn = Bunny.new
conn.start

# open a channel
ch = conn.create_channel

# declare a queue
q  = ch.queue("test1")

# declare default direct exchange which is bound to all queues
e  = ch.default_exchange

# publish a message to the exchange which then gets routed to the queue
e.publish("Hello, everybody!", :routing_key => 'test1')

# fetch a message from the queue
delivery_info, metadata, payload = q.pop

puts "This is the message: #{payload}"

# close the connection
conn.stop
```


## Community & Getting Help

### Getting Started

For a 15 minute tutorial using more practical examples, see [Getting Started with RabbitMQ and Ruby using Bunny](http://rubybunny.info/articles/getting_started.html).

### Guides

Other documentation guides are available at [rubybunny.info](http://rubybunny.info).

### API Reference

[Bunny API Reference](http://rubydoc.info/github/ruby-amqp/bunny/master/frames) is available at rubydoc.info.

### Getting Help

Please use [Ruby RabbitMQ clients Google Group](http://groups.google.com/group/ruby-amqp) for any questions you may
have.

For news and updates, [follow @rubyamqp](http://twitter.com/rubyamqp) on Twitter.


## Other Ruby RabbitMQ Clients

Other widely used Ruby RabbitMQ clients are [Hot Bunnies](http://github.com/ruby-amqp/hot_bunnies) (JRuby-only) and [amqp gem](http://rubyamqp.info).
Both are mature libraries and require RabbitMQ 2.x or 3.x.


## Other Resources

* [AMQP 0.9.1 model explained](http://www.rabbitmq.com/tutorials/amqp-concepts.html): introductory explanation of the AMQP v0.9.1 specification with particular reference to RabbitMQ.


## Links

* [Source code](http://github.com/ruby-amqp/bunny)
* [Blog](http://bunnyamqp.wordpress.com)
