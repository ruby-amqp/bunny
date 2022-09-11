---
title: "Concurrency in Bunny and Applications That Use It"
layout: article
---

## About this guide

This guide covers concurrency in Bunny, concurrency safety
of key public API parts, potential for parallelism on Ruby runtimes
that support it, and related issues.

This work is licensed under a <a rel="license"
href="http://creativecommons.org/licenses/by/3.0/">Creative Commons
Attribution 3.0 Unported License</a> (including images and
stylesheets). The source is available [on
GitHub](https://github.com/ruby-amqp/rubybunny.info).


## What version of Bunny does this guide cover?

This guide covers Bunny 2.11.0 and later versions.


## Concurrency in Bunny Design

Starting with Bunny 0.9, Bunny is developed with concurrency in mind.
This means several things:

 * Bunny avoids some well known concurrency problems in [amqp gem](http://rubyamqp.info),
   most notably long running operations in message handlers blocking event loop and thus all
   I/O activity in the library.

 * Connection (`Bunny::Session`) assumes there will be concurrent publishers
   and consumers.

 * Parts of the library (most notably `Bunny::Channel`) are designed to assume they are **not shared between threads**.

 * Parts of the library can take advantage of parallelism on runtimes that
   provide it.

 * Parts of the library that previously were not concurrent now provide
   concurrency controls.


## Enabling Long Running Delivery Handlers

Unlike [amqp gem](http://rubyamqp.info), Bunny does not depend on any
opinionated networking library. Instead, it maintains its own I/O
activity loop in a separate thread, one per connection. The loop is
responsible for reading data from the socket, deserializing it and
passing over to the connection that instantiated the loop.

Not depending on a global event loop allows Bunny-based applications
that consume messages to have long running delivery handlers that
do not affect other network activity.

Communication between I/O loop and connection is almost completely
uni-directional. Writes do not happen in I/O loop thread.


## Synchronized Writes

Connections in Bunny will synchronize writes both for messages
and at the socket level. This means that publishing on
a shared connection from multiple threads is safe but
**only if every publishing thread uses a separate channel**.


## Sharing Channels Between Threads

Channels **must not** be shared between threads.
When client publishes a message, at least 2 (typically 3) frames
are sent on the wire:

 * AMQP 0.9.1 method, `basic.publish`
 * Message metadata
 * Message payload

This means that without synchronization on, publishing from multiple
threads on a shared channel may result in frames being sent
to RabbitMQ out of order, e.g.:

```
[basic.publish 1][basic.publish 2][content metadata 1][content body 1][content metadata 2][content metadata 2]
```

There are other potential conflicts arising from frame interleaving.
It is, however, safe to process deliveries in multiple threads
if multi-message acknowledgements are not used.


## Consumer Work Pools

Every channel maintains a fixed size thread pool used to dispatch
deliveries (messages pushed by RabbitMQ to consumers). By default
every pool has size of 1 to guarantee ordered message processing
by default.

Applications can provide alternative consumer pool size:

``` ruby
# nil will cause channel id to be allocated automatically.
# 16 is consumer work pool size.
ch = conn.create_channel(nil, 16)
```

Consumer work pool is not started by default and will be
created when the first consumer is added on the channel.
When the last consumer is cancelled, consumer work pool
will be shut down. This ensures that channels that
are only used to publish messages do not keep around threads
that do nothing.

It also reduces the amount of time it takes to open
a channel, which is desirable for applications doing
heavy request/reply (RPC) communication.


## Mutex Reentrancy

Standard Ruby mutex implementation is not reentrant. This is highly
annoying to many developers. Standard Ruby library provides
a reentrant mutex implementation: `Monitor`. Monitors are reentrant
at the cost of about 5-6% lower throughput on most workloads.

It is possible to switch to the original mutex implementation, `Mutex`:

``` ruby
conn = Bunny.new(:mutex_impl => Mutex)
```



## Wrapping Up

Bunny 0.9+ was created to be used in concurrent applications. While
Bunny tries to do a reasonably well job of protecting the user from
concurrency hazards in common scenarios, some usage scenarios
(primarily sharing channels between publishing threads) should
be avoided.

Especially for message consumers, Bunny can take advantage of
parallelism on runtimes that support it. More parts of the library
may be parallized over time.


## What to Read Next

The documentation is organized as [a number of
guides](/articles/guides.html), covering various topics.

We recommend that you read the following guides first, if possible, in
this order:

 * [RabbitMQ Extensions to AMQP 0.9.1](/articles/extensions.html)
 * [Error Handling and Recovery](/articles/error_handling.html)
 * [Troubleshooting](/articles/troubleshooting.html)
 * [Using TLS (SSL) Connections](/articles/tls.html)



## Tell Us What You Think!

Please take a moment to tell us what you think about this guide [on
Twitter](http://twitter.com/rubyamqp) or the [Bunny mailing
list](https://groups.google.com/forum/#!forum/ruby-amqp).

Let us know what was unclear or what has not been covered. Maybe you
do not like the guide style or grammar or discover spelling
mistakes. Reader feedback is key to making the documentation better.
