# Bunny, a Ruby RabbitMQ Client

Bunny is a RabbitMQ client that focuses on ease of use. It
is feature complete, supports all recent RabbitMQ features and does not
have any heavyweight dependencies.


## I Know What RabbitMQ and Bunny are, How Do I Get Started?

[Right here](https://www.rabbitmq.com/getstarted.html)!


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

 * CRuby 3.2 through 3.4 (inclusive)
 * [TruffleRuby](https://www.graalvm.org/ruby/)

For environments that use TLS, Bunny expects Ruby installations to use a recent enough OpenSSL version that
**includes support for [TLS 1.3](https://www.rabbitmq.com/docs/ssl#tls1.3)**.

### JRuby

Bunny no longer supports JRuby.

JRuby users should use [March Hare](http://rubymarchhare.info), which has a similar API
and is built on top of the RabbitMQ Java client specifically for JRuby.


## Supported RabbitMQ Versions

Modern Bunny releases target [currently community supported RabbitMQ release series](https://www.rabbitmq.com/release-information).

The protocol implemented by Bunny was first introduced in RabbitMQ 2.0 and has evolved
via extensions and with next to no breaking changes, so all key Bunny operations can be used with a wide range
of RabbitMQ versions, accounting for the few potentially breaking changes they
may introduce, e.g. the idempotency of `queue.delete` operations.


## Change Log

[Change log](https://github.com/ruby-amqp/bunny/blob/main/ChangeLog.md).


## Installation & Bundler Dependency

### Most Recent Release

[![Gem Version](https://badge.fury.io/rb/bunny.svg)](http://badge.fury.io/rb/bunny)

### Bundler Dependency

To use Bunny in a project managed with Bundler:

``` ruby
gem "bunny", ">= 2.23.0"
```

### With Rubygems

To install Bunny with RubyGems:

```
gem install bunny
```


## Quick Start

Below is a small snippet that demonstrates how to publish
and synchronously consume ("pull API") messages with Bunny.

For a 15 minute tutorial using more practical examples, see [Getting Started with RabbitMQ and Ruby using Bunny](https://www.rabbitmq.com/tutorials/tutorial-one-ruby.html).

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

For a 15 minute tutorial using more practical examples, see [Getting Started with RabbitMQ and Ruby using Bunny](https://github.com/ruby-amqp/bunny/blob/main/docs/guides/getting_started.md).

### Guides

Bunny documentation guides are [under `docs/guides` in this repository](https://github.com/ruby-amqp/bunny/tree/main/docs/guides):

 * [Queues and Consumers](https://github.com/ruby-amqp/bunny/tree/main/docs/guides/queues.md)
 * [Exchanges and Publishers](https://github.com/ruby-amqp/bunny/tree/main/docs/guides/exchanges.md)
 * [AMQP 0.9.1 Model Explained](http://www.rabbitmq.com/tutorials/amqp-concepts.html)
 * [Connecting to RabbitMQ](https://github.com/ruby-amqp/bunny/tree/main/docs/guides/connecting.md)
 * [Error Handling and Recovery](https://github.com/ruby-amqp/bunny/tree/main/docs/guides/error_handling.md)
 * [TLS/SSL Support](https://github.com/ruby-amqp/bunny/tree/main/docs/guides/tls.md)
 * [Bindings](https://github.com/ruby-amqp/bunny/tree/main/docs/guides/bindings.md)
 * [Using RabbitMQ Extensions with Bunny](https://github.com/ruby-amqp/bunny/tree/main/docs/guides/extensions.md)
 * [Durability and Related Matters](https://github.com/ruby-amqp/bunny/tree/main/docs/guides/durability.md)

Some highly relevant RabbitMQ documentation guides:

 * [Connections](https://www.rabbitmq.com/docs/connections)
 * [Channels](https://www.rabbitmq.com/docs/channels)
 * [Queues](https://www.rabbitmq.com/docs/queues)
 * [Quorum queues](https://www.rabbitmq.com/docs/quorum-queues)
 * [Streams](https://rabbitmq.com/docs/streams) (Bunny can perform basic operations on streams even though it does not implement the [RabbitMQ Stream protocol](https://github.com/rabbitmq/rabbitmq-server/blob/v4.0.x/deps/rabbitmq_stream/docs/PROTOCOL.adoc))
 * [Publishers](https://www.rabbitmq.com/docs/publishers)
 * [Consumers](https://www.rabbitmq.com/docs/consumers)
 * Data safety: publisher and consumer [Confirmations](https://www.rabbitmq.com/docs/confirms)
 * [Production Checklist](https://www.rabbitmq.com/docs/production-checklist)

### API Reference

[Bunny API Reference](http://reference.rubybunny.info/).


## Community and Getting Help

### Mailing List

Please use [GitHub Discussions](https://github.com/ruby-amqp/bunny/discussions) for questions.

GitHub issues should be used for specific, well understood, actionable
maintainers and contributors can work on.

We encourage you to keep an eye on [RabbitMQ Discussions](https://github.com/rabbitmq/rabbitmq-server/discussions),
join the [RabbitMQ mailing list](https://groups.google.com/forum/#!forum/rabbitmq-users)
and the [RabbitMQ Discord server](https://rabbitmq.com/discord).


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
