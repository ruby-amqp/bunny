# Bunny, a Ruby RabbitMQ Client

Bunny is a RabbitMQ client that focuses on ease of use. It
is feature complete, supports all recent RabbitMQ features and does not
have any heavyweight dependencies.


## I Know What RabbitMQ and Bunny are, How Do I Get Started?

[Right here](http://rubybunny.info/articles/getting_started.html)!


## What is Bunny Good For?

One can use Bunny to make Ruby applications interoperate with other
applications (both built in Ruby and not). Complexity and size may vary from
simple work queues to complex multi-stage data processing workflows that involve
many applications built with all kinds of technologies.

Specific examples:

 * Events collectors, metrics & analytics applications can aggregate events produced by various applications
   (Web and not) in the company network.

 * A Web application may route messages to a Java app that works
   with SMS delivery gateways.

 * MMO games can use flexible routing RabbitMQ provides to propagate event notifications to players and locations.

 * Price updates from public markets or other sources can be distributed between interested parties, from trading systems to points of sale in a specific geographic region.

 * Content aggregators may update full-text search and geospatial search indexes
   by delegating actual indexing work to other applications over RabbitMQ.

 * Companies may provide streaming/push APIs to their customers, partners
   or just general public.

 * Continuous integration systems can distribute builds between multiple machines with various hardware and software
   configurations using advanced routing features of RabbitMQ.

 * An application that watches updates from a real-time stream (be it markets data
   or Twitter stream) can propagate updates to interested parties, including
   Web applications that display that information in the real time.


## Supported Ruby Versions

Modern Bunny versions support

 * CRuby 2.5 through 3.0 (inclusive)

Bunny works sufficiently well on JRuby but there are known
JRuby bugs in versions prior to JRuby 9000 that cause high CPU burn. JRuby users should
use [March Hare](http://rubymarchhare.info).

Bunny `1.7.x` was the last version to support CRuby 1.9.3 and 1.8.7


## Supported RabbitMQ Versions

Bunny `1.5.0` and later versions only support RabbitMQ `3.3+`.
Bunny `1.4.x` and earlier supports RabbitMQ 2.x and 3.x.


## Change Log

Bunny is a mature library (started in early 2009) with
a stable public API.

Change logs per release series:

 * [master](https://github.com/ruby-amqp/bunny/blob/master/ChangeLog.md)
 * [2.18.x](https://github.com/ruby-amqp/bunny/blob/2.18.x-stable/ChangeLog.md)
 * [2.17.x](https://github.com/ruby-amqp/bunny/blob/2.17.x-stable/ChangeLog.md)



## Installation & Bundler Dependency

### Most Recent Release

[![Gem Version](https://badge.fury.io/rb/bunny.svg)](http://badge.fury.io/rb/bunny)

### With Rubygems

To install Bunny with RubyGems:

```
gem install bunny
```

### Bundler Dependency

To use Bunny in a project managed with Bundler:

``` ruby
gem "bunny", ">= 2.18.0"
```


## Quick Start

Below is a small snippet that demonstrates how to publish
and synchronously consume ("pull API") messages with Bunny.

For a 15 minute tutorial using more practical examples, see [Getting Started with RabbitMQ and Ruby using Bunny](http://rubybunny.info/articles/getting_started.html).

``` ruby
require "bunny"

# Start a communication session with RabbitMQ
conn = Bunny.new
conn.start

# open a channel
ch = conn.create_channel
ch.confirm_select

# declare a queue
q  = ch.queue("test1")
q.subscribe(manual_ack: true) do |delivery_info, metadata, payload|
  puts "This is the message: #{payload}"
  # acknowledge the delivery so that RabbitMQ can mark it for deletion
  ch.ack(delivery_info.delivery_tag)
end

# publish a message to the default exchange which then gets routed to this queue
q.publish("Hello, everybody!")

# await confirmations from RabbitMQ, see
# https://www.rabbitmq.com/publishers.html#data-safety for details
ch.wait_for_confirms

# give the above consumer some time consume the delivery and print out the message
sleep 1

puts "Done"

ch.close
# close the connection
conn.close
```


## Documentation

### Getting Started

For a 15 minute tutorial using more practical examples, see [Getting Started with RabbitMQ and Ruby using Bunny](http://rubybunny.info/articles/getting_started.html).

### Guides

Bunny documentation guides are available at [rubybunny.info](http://rubybunny.info):

 * [Queues and Consumers](http://rubybunny.info/articles/queues.html)
 * [Exchanges and Publishers](http://rubybunny.info/articles/exchanges.html)
 * [AMQP 0.9.1 Model Explained](http://www.rabbitmq.com/tutorials/amqp-concepts.html)
 * [Connecting to RabbitMQ](http://rubybunny.info/articles/connecting.html)
 * [Error Handling and Recovery](http://rubybunny.info/articles/error_handling.html)
 * [TLS/SSL Support](http://rubybunny.info/articles/tls.html)
 * [Bindings](http://rubybunny.info/articles/bindings.html)
 * [Using RabbitMQ Extensions with Bunny](http://rubybunny.info/articles/extensions.html)
 * [Durability and Related Matters](http://rubybunny.info/articles/durability.html)

Some highly relevant RabbitMQ documentation guides:

 * [Connections](https://www.rabbitmq.com/connections.html)
 * [Channels](https://www.rabbitmq.com/channels.html)
 * [Queues](https://www.rabbitmq.com/queues.html)
 * [Publishers](https://www.rabbitmq.com/publishers.html)
 * [Consumers](https://www.rabbitmq.com/consumers.html)
 * Data safety: publisher and consumer [Confirmations](https://www.rabbitmq.com/confirms.html)
 * [Production Checklist](https://www.rabbitmq.com/production-checklist.html)

### API Reference

[Bunny API Reference](http://reference.rubybunny.info/).


## Community and Getting Help

### Mailing List

[Bunny has a mailing list](http://groups.google.com/group/ruby-amqp). Please use it for all questions,
investigations, and discussions. GitHub issues should be used for specific, well understood, actionable
maintainers and contributors can work on.

We encourage you to also join the [RabbitMQ mailing list](https://groups.google.com/forum/#!forum/rabbitmq-users)
mailing list. Feel free to ask any questions that you may have.


## Continuous Integration

[![Build Status](https://travis-ci.org/ruby-amqp/bunny.svg)](https://travis-ci.org/ruby-amqp/bunny/)


### News & Announcements on Twitter

To subscribe for announcements of releases, important changes and so on, please follow [@rubyamqp](https://twitter.com/#!/rubyamqp) on Twitter.

More detailed announcements can be found in the [RabbitMQ Ruby clients blog](http://blog.rubyrabbitmq.info).


### Reporting Issues

If you find a bug you understand well, poor default, incorrect or unclear piece of documentation,
or missing feature, please [file an
issue](http://github.com/ruby-amqp/bunny/issues) on GitHub.

Please use [Bunny's mailing list](http://groups.google.com/group/ruby-amqp) for questions,
investigations, and discussions. GitHub issues should be used for specific, well understood, actionable
maintainers and contributors can work on.

When filing an issue, please specify which Bunny and RabbitMQ versions you
are using, provide recent RabbitMQ log file contents, full exception stack traces,
and steps to reproduce (or failing test cases).


## Other Ruby RabbitMQ Clients

The other widely used Ruby RabbitMQ client is [March Hare](http://rubymarchhare.info) (JRuby-only).
It's a mature library that require RabbitMQ 3.3.x or later.


## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for more information
about running various test suites.


## License

Released under the MIT license.
