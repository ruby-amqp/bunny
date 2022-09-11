---
title: "Working with RabbitMQ bindings from Ruby with Bunny"
layout: article
---

## About This Guide

This guide covers bindings in AMQP 0.9.1, what they are, what role
they play and how to accomplish typical operations using Bunny.

This work is licensed under a <a rel="license"
href="http://creativecommons.org/licenses/by/3.0/">Creative Commons
Attribution 3.0 Unported License</a> (including images and
stylesheets). The source is available [on
GitHub](https://github.com/ruby-amqp/rubybunny.info).


## What version of Bunny does this guide cover?

This guide covers Bunny 2.11.0 and later versions.


## Bindings in AMQP 0.9.1

Learn more about how bindings fit into the AMQP Model in the [AMQP
0.9.1 Model
Concepts](http://www.rabbitmq.com/tutorials/amqp-concepts.html) guide.


## What Are AMQP 0.9.1 Bindings

Bindings are rules that exchanges use (among other things) to route
messages to queues. To instruct an exchange E to route messages to a
queue Q, Q has to _be bound_ to E.  Bindings may have an optional
_routing key_ attribute used by some exchange types. The purpose of
the routing key is to selectively match only specific (matching)
messages published to an exchange to the bound queue. In other words,
the routing key acts like a filter.

To draw an analogy:

 * Queue is like your destination in New York city
 * Exchange is like JFK airport
 * Bindings are routes from JFK to your destination. There may be no way, or more than one way, to reach it

Some exchange types use routing keys while some others do not (routing
messages unconditionally or based on message metadata). If an AMQP
message cannot be routed to any queue (for example, because there are
no bindings for the exchange it was published to), it is either
dropped or returned to the publisher, depending on the message
attributes that the publisher has set.

If an application wants to connect a queue to an exchange, it needs to
_bind_ them. The opposite operation is called _unbinding_.

## Binding Queues to Exchanges

In order to receive messages, a queue needs to be bound to at least
one exchange. Most of the time binding is explicit (done by
applications).  To bind a queue to an exchange, use
`Bunny::Queue#bind` where the argument passed can be either an
`Bunny::Exchange` instance or a string.

``` ruby
q.bind(x)
```

The same example using a string without a callback:

``` ruby
q.bind("amq.fanout")
```


## Unbinding queues from exchanges

To unbind a queue from an exchange use `Bunny::Queue#unbind`:

``` ruby
q.unbind(x)
```
<span class="note">Trying to unbind a queue from an exchange that the queue was never bound to will result in a channel-level exception.</span>


## Exchange-to-Exchange Bindings

Exchange-to-Exchange bindings is a RabbitMQ extension to AMQP
0.9.1. It is covered in the [RabbitMQ extensions
guide](/articles/extensions.html).


## Bindings, Routing and Returned Messages

### How RabbitMQ Routes Messages

After a message reaches RabbitMQ and before it reaches a consumer,
several things happen:

 * RabbitMQ needs to find one or more queues that the message needs to be routed to, depending on type of exchange
 * RabbitMQ puts a copy of the message into each of those queues or decides to return the message to the publisher
 * RabbitMQ pushes message to consumers on those queues or waits for applications to fetch them on demand

A more in-depth description is this:

 * RabbitMQ needs to consult bindings list for the exchange the message was published to in order to find one or more queues that the message needs to be routed to (step 1)
 * If there are no suitable queues found during step 1 and the message was published as mandatory, it is returned to the publisher (step 1b)
 * If there are suitable queues, a _copy_ of the message is placed into each one (step 2)
 * If the message was published as mandatory, but there are no active consumers for it, it is returned to the publisher (step 2b)
 * If there are active consumers on those queues and the basic.qos setting permits, message is pushed to those consumers (step 3)

The important thing to take away from this is that messages may or may
not be routed and it is important for applications to handle
unroutable messages.

### Handling of Unroutable Messages

Unroutable messages are either dropped or returned to
producers. RabbitMQ extensions can provide additional ways of handling
unroutable messages: for example, RabbitMQ's [Alternate Exchanges
extension](http://www.rabbitmq.com/ae.html) makes it possible to route
unroutable messages to another exchange.  Bunny support for it is
documented in the [RabbitMQ Extensions
guide](/articles/extensions.html).

Bunny provides a way to handle returned messages with the
`Bunny::Exchange#on_return` method:

``` ruby
x.on_return do |basic_return, properties, payload|
  puts "#{payload} was returned! reply_code = #{basic_return.reply_code}, reply_text = #{basic_return.reply_text}"
end
```

[Exchanges and Publishing](/articles/exchanges.html) documentation
guide provides more information on the subject, including full code
examples.


## What to Read Next

The documentation is organized as [a number of guides](/articles/guides.html), covering various topics.

We recommend that you read the following guides first, if possible, in this order:

 * [RabbitMQ Extensions to AMQP 0.9.1](/articles/extensions.html)
 * [Durability and Related Matters](/articles/durability.html)
 * [Error Handling and Recovery](/articles/error_handling.html)
 * [Troubleshooting](/articles/troubleshooting.html)
 * [Using TLS (SSL) Connections](/articles/tls.html)


## Tell Us What You Think!

Please take a moment to tell us what you think about this guide [on Twitter](http://twitter.com/rubyamqp) or the [Bunny mailing list](https://groups.google.com/forum/#!forum/ruby-amqp)

Let us know what was unclear or what has not been covered. Maybe you do not like the guide style or grammar or discover spelling mistakes. Reader feedback is key to making the documentation better.
