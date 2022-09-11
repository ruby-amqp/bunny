---
title: "Working with RabbitMQ extensions from Ruby with Bunny"
layout: article
---

## About This Guide

Bunny 0.9 supports all [RabbitMQ extensions to AMQP 0.9.1](http://www.rabbitmq.com/extensions.html):

  * [Publisher confirms](http://www.rabbitmq.com/confirms.html)
  * [Negative acknowledgements](http://www.rabbitmq.com/nack.html) (basic.nack)
  * [Exchange-to-Exchange Bindings](http://www.rabbitmq.com/e2e.html)
  * [Alternate Exchanges](http://www.rabbitmq.com/ae.html)
  * [Per-queue Message Time-to-Live](http://www.rabbitmq.com/ttl.html#per-queue-message-ttl)
  * [Per-message Time-to-Live](http://www.rabbitmq.com/ttl.html#per-message-ttl)
  * [Queue Leases](http://www.rabbitmq.com/ttl.html#queue-ttl)
  * [Consumer Cancellation Notifications](http://www.rabbitmq.com/consumer-cancel.html)
  * [Sender-selected Distribution](http://www.rabbitmq.com/sender-selected.html)
  * [Dead Letter Exchanges](http://www.rabbitmq.com/dlx.html)
  * [Validated user_id](http://www.rabbitmq.com/validated-user-id.html)

This guide briefly describes how to use these extensions with Bunny.

This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by/3.0/">Creative Commons Attribution 3.0 Unported License</a>
(including images and stylesheets). The source is available [on GitHub](https://github.com/ruby-amqp/rubybunny.info).

## What version of Bunny does this guide cover?

This guide covers Bunny 0.9.


## Enabling RabbitMQ Extensions

You don't need to require any additional files to make Bunny 0.9 support RabbitMQ extensions.
The support is built into the core.

## Per-queue Message Time-to-Live

Per-queue Message Time-to-Live (TTL) is a RabbitMQ extension to AMQP 0.9.1 that allows developers to control how long
a message published to a queue can live before it is discarded.
A message that has been in the queue for longer than the configured TTL is said to be dead. Dead messages will not be delivered
to consumers and cannot be fetched using the *basic.get* operation (`Bunny::Queue#pop`).

Message TTL is specified using the *x-message-ttl* argument on declaration. With Bunny, you pass it to `Bunny::Queue#initialize` or `Bunny::Channel#queue`:

``` ruby
# 1000 milliseconds
channel.queue("", :arguments => { "x-message-ttl" => 1000 })
```

When a published message is routed to multiple queues, each of the queues gets a _copy of the message_. If the message subsequently dies in one of the queues,
it has no effect on copies of the message in other queues.

### Example

The example below sets the message TTL for a new server-named queue to be 1000 milliseconds. It then publishes several messages that are routed to the queue and tries
to fetch messages using the *basic.get* AMQP 0.9.1 method (`Bunny::Queue#pop` after 0.7 and 1.5 seconds:

``` ruby
#!/usr/bin/env ruby
# encoding: utf-8

require "bunny"

puts "=> Using per-queue message TTL"
puts

conn = Bunny.new
conn.start

ch   = conn.create_channel
x    = ch.fanout("amq.fanout")
q    = ch.queue("", :exclusive => true, :arguments => {"x-message-ttl" => 1000}).bind(x)

10.times do |i|
  x.publish("Message #{i}")
end

sleep 0.7
_, _, content1 = q.pop
puts "Fetched #{content1.inspect} after 0.7 second"

sleep 0.8
_, _, content2 = q.pop
msg = if content2
        content2.inspect
      else
        "nothing"
      end
puts "Fetched #{msg} after 1.5 second"

sleep 0.7
puts "Closing..."
conn.close
```

### Learn More

See also rabbitmq.com section on [Per-queue Message TTL](http://www.rabbitmq.com/ttl.html#per-queue-message-ttl)

## Publisher Confirms (Publisher Acknowledgements)

In some situations it is essential that messages are reliably delivered to the RabbitMQ broker and not lost on the way. The only reliable ways of assuring message delivery are by using publisher confirms or [transactions](http://www.rabbitmq.com/semantics.html).

The [Publisher Confirms AMQP extension](http://www.rabbitmq.com/blog/2011/02/10/introducing-publisher-confirms/) was designed to solve the reliable publishing problem in a more lightweight way compared to transactions.

Publisher confirms are similar to message acknowledgements (documented in the [Queues and Consumers](/articles/queues.html) guide), but involve
a publisher and a RabbitMQ node instead of a consumer and a RabbitMQ node.

![RabbitMQ Message Acknowledgements](https://github.com/ruby-amqp/amqp/raw/master/docs/diagrams/006_amqp_091_message_acknowledgements.png)

![RabbitMQ Publisher Confirms](https://github.com/ruby-amqp/amqp/raw/master/docs/diagrams/007_rabbitmq_publisher_confirms.png)

### How To Use It With Bunny 0.9+

To use publisher confirms, first put the channel into confirmation mode using the `Bunny::Channel#confirm_select` method:

```
channel.confirm_select
```

From this moment on, every message published on this channel will cause the channel's _publisher index_ (message counter) to be incremented.
It is possible to access the index using `Bunny::Channel#next_publish_seq_no` method. To check whether the channel is in confirmation mode,
use the `Bunny::Channel#using_publisher_confirmations?` method:

``` ruby
ch.using_publisher_confirmations? # => false
ch.confirm_select
ch.using_publisher_confirmations? # => true
```

### Example

``` ruby
#!/usr/bin/env ruby
# encoding: utf-8

require "bunny"

puts "=> Using publisher confirms"
puts

conn = Bunny.new
conn.start

ch   = conn.create_channel
x    = ch.fanout("amq.fanout")
q    = ch.queue("", :exclusive => true).bind(x)

# Put channel in confirmation mode
ch.confirm_select

1000.times do
  x.publish("")
end

# Block until all messages have been confirmed
success = ch.wait_for_confirms

if !success
  ch.nacked_set.each do |n|
    # Do something with the nacked message ID
  end
end

sleep 0.2
puts "Processed all published messages. #{q.name} now has #{q.message_count} messages."

sleep 0.5
puts "Closing..."
conn.close
```

In the example above, the `Bunny::Channel#wait_for_confirms` method blocks (waits) until all of the published messages are confirmed by the RabbitMQ broker. **Note** that a message may be nacked by the broker if, for some reason, it cannot take responsibility for the message. In that case, the `wait_for_confirms` method will return `false` and there is also a Ruby `Set` of nacked message IDs (`channel.nacked_set`) that can be inspected and dealt with as required.

### Learn More

See also rabbitmq.com section on [Publisher Confirms](http://www.rabbitmq.com/confirms.html)

## basic.nack

The AMQP 0.9.1 specification defines the basic.reject method that allows clients to reject individual, delivered messages, instructing the broker to either
discard them or requeue them. Unfortunately, basic.reject provides no support for negatively acknowledging messages in bulk.

To solve this, RabbitMQ supports the basic.nack method that provides all of the functionality of basic.reject whilst also allowing for bulk processing of messages.

### How To Use It With Bunny 0.9+

Bunny exposes `basic.nack` via the `Bunny::Channel#nack` method, similar to `Bunny::Channel#ack` and `Bunny::Channel#reject`:

``` ruby
# nack multiple messages at once
subject.nack(delivery_info.delivery_tag, false, true)

# nack a single message at once, the same as ch.reject(delivery_info.delivery_tag, false)
subject.nack(delivery_info.delivery_tag, false)
```

### Example

``` ruby
#!/usr/bin/env ruby
# encoding: utf-8

require "bunny"

puts "=> Using publisher confirms"
puts

conn = Bunny.new
conn.start

ch   = conn.create_channel
q    = ch.queue("", :exclusive => true)

20.times do
  q.publish("")
end

20.times do
  delivery_info, _, _ = q.pop(:manual_ack => true)

  if delivery_info.delivery_tag == 20
    # requeue them all at once with basic.nack
    ch.nack(delivery_info.delivery_tag, true, true)
  end
end

puts "Queue #{q.name} still has #{q.message_count} messages in it"

sleep 0.7
puts "Disconnecting..."
conn.close
```

### Learn More

See also rabbitmq.com section on [basic.nack](http://www.rabbitmq.com/nack.html)

## Alternate Exchanges

The Alternate Exchanges RabbitMQ extension to AMQP 0.9.1 allows developers to define "fallback" exchanges
where unroutable messages will be sent.

### How To Use It With Bunny 0.9+

To specify exchange A as an alternate exchange to exchange B, specify the 'alternate-exchange' argument on declaration of B:

``` ruby
ch   = conn.create_channel
x1   = ch.fanout("bunny.examples.ae.exchange1", :auto_delete => true, :durable => false)
x2   = ch.fanout("bunny.examples.ae.exchange2", :auto_delete => true, :durable => false, :arguments => {
                   "alternate-exchange" => x1.name
                 })
```

### Example

``` ruby
#!/usr/bin/env ruby
# encoding: utf-8

require "bunny"

puts "=> Using alternate exchanges"
puts

conn = Bunny.new
conn.start

ch   = conn.create_channel
x1   = ch.fanout("bunny.examples.ae.exchange1", :auto_delete => true, :durable => false)
x2   = ch.fanout("bunny.examples.ae.exchange2", :auto_delete => true, :durable => false, :arguments => {
                   "alternate-exchange" => x1.name
                 })
q    = ch.queue("", :exclusive => true)
q.bind(x1)

x2.publish("")

sleep 0.2
puts "Queue #{q.name} now has #{q.message_count} message in it"

sleep 0.7
puts "Disconnecting..."
conn.close
```

### Learn More

See also rabbitmq.com section on [Alternate Exchanges](http://www.rabbitmq.com/ae.html)

## Exchange-To-Exchange Bindings

RabbitMQ supports [exchange-to-exchange bindings](http://www.rabbitmq.com/e2e.html) to allow even richer routing topologies as well as a backbone for
some other features (e.g. tracing).

### How To Use It With Bunny 0.9+

Bunny 0.9 exposes it via `Bunny::Exchange#bind` which is semantically the same as `Bunny::Queue#bind` but binds
two exchanges:

``` ruby
# x2 will be the source
x1.bind(x2, :routing_key => "americas.north.us.ca.*")
```

### Example

``` ruby
#!/usr/bin/env ruby
# encoding: utf-8

require "bunny"

puts "=> Using exchange-to-exchange bindings"
puts

conn = Bunny.new
conn.start

ch   = conn.create_channel
x1   = ch.fanout("bunny.examples.e2e.exchange1", :auto_delete => true, :durable => false)
x2   = ch.fanout("bunny.examples.e2e.exchange2", :auto_delete => true, :durable => false)
# x1 will be the source
x2.bind(x1)

q    = ch.queue("", :exclusive => true)
q.bind(x2)

x1.publish("")

sleep 0.2
puts "Queue #{q.name} now has #{q.message_count} message in it"

sleep 0.7
puts "Disconnecting..."
conn.close
```

### Learn More

See also rabbitmq.com section on [Exchange-to-Exchange Bindings](http://www.rabbitmq.com/e2e.html)

## Consumer Cancellation Notifications

### How To Use It With Bunny 0.9+

In order to use consumer cancellation notifications, you need to use consumer objects (documented in the [Queues and Consumers guide](/articles/queues.html)).
When a consumer is cancelled, the `#handle_cancellation` method will be called on it. To register a consumer that is an object
and not just message handler block, use `Bunny::Queue#subscribe_with` instead of `Bunny::Queue#subscribe`:

``` ruby
ch   = conn.create_channel

module Bunny
  module Examples
    class ExampleConsumer < Bunny::Consumer
      def cancelled?
        @cancelled
      end

      def handle_cancellation(basic_cancel)
        puts "#{@consumer_tag} was cancelled"
        @cancelled = true
      end
    end
  end
end

q    = ch.queue("", :exclusive => true)
c    = Bunny::Examples::ExampleConsumer.new(ch, q)
q.subscribe_with(c)
```

### Example

``` ruby
#!/usr/bin/env ruby
# encoding: utf-8

require "bunny"

puts "=> Using consumer cancellation"
puts

conn = Bunny.new
conn.start

ch   = conn.create_channel

module Bunny
  module Examples
    class ExampleConsumer < Bunny::Consumer
      def cancelled?
        @cancelled
      end

      def handle_cancellation(basic_cancel)
        puts "#{@consumer_tag} was cancelled"
        @cancelled = true
      end
    end
  end
end

q    = ch.queue("", :exclusive => true)
c    = Bunny::Examples::ExampleConsumer.new(ch, q)
q.subscribe_with(c)

sleep 0.1
q.delete

sleep 0.1
puts "Disconnecting..."
conn.close
```

### Learn More

See also rabbitmq.com section on [Consumer Cancellation Notifications](http://www.rabbitmq.com/consumer-cancel.html)

## Queue Leases

Queue Leases is a RabbitMQ feature that lets you set for how long a queue is allowed to be *unused*. After that moment,
it will be deleted. *Unused* here means that the queue

 * has no consumers
 * is not redeclared
 * no message fetches happened (using `basic.get` AMQP 0.9.1 method, that is, `Bunny::Queue#pop` in Bunny)

### How To Use It With Bunny 0.9+

Use the `"x-expires"` optional queue argument to set how long the queue will be allowed to be unused in milliseconds. After that time,
the queue will be removed by RabbitMQ.

``` ruby
ch.queue("", :exclusive => true, :arguments => {"x-expires" => 300})
```

### Example

``` ruby
#!/usr/bin/env ruby
# encoding: utf-8

require "bunny"

puts "=> Demonstrating queue TTL (queue leases)"
puts

conn = Bunny.new
conn.start

ch   = conn.create_channel
q    = ch.queue("", :exclusive => true, :arguments => {"x-expires" => 300})

sleep 0.4
begin
  # this will raise because the queue is already deleted
  q.message_count
rescue Bunny::NotFound => nfe
  puts "Got a 404 response: the queue has already been removed"
end

sleep 0.7
puts "Closing..."
conn.close
```

### Learn More

See also rabbitmq.com section on [Queue Leases](http://www.rabbitmq.com/ttl.html#queue-ttl)

## Per-Message Time-to-Live

A TTL can be specified on a per-message basis, by setting the `:expiration` property when publishing.

### How To Use It With Bunny 0.9+

`Bunny::Exchange#publish` recognizes the `:expiration` option that is message time-to-live (TTL) in milliseconds:

``` ruby
# 1 second
x.publish("", :expiration => 1000)

# 5 minutes
x.publish("", :expiration => (5 * 60 * 1000))
```

### Example

``` ruby
#!/usr/bin/env ruby
# encoding: utf-8

require "bunny"

puts "=> Using per-message TTL"
puts

conn = Bunny.new
conn.start

ch   = conn.create_channel
x    = ch.fanout("amq.fanout")
q    = ch.queue("", :exclusive => true).bind(x)

10.times do |i|
  x.publish("Message #{i}", :expiration => 1000)
end

sleep 0.7
_, _, content1 = q.pop
puts "Fetched #{content1.inspect} after 0.7 second"

sleep 0.8
_, _, content2 = q.pop
msg = if content2
        content2.inspect
      else
        "nothing"
      end
puts "Fetched #{msg} after 1.5 second"

sleep 0.7
puts "Closing..."
conn.close
```

### Learn More

See also rabbitmq.com section on [Per-message TTL](http://www.rabbitmq.com/ttl.html#per-message-ttl)

## Sender-Selected Distribution

Generally, the RabbitMQ model assumes that the broker will do the routing work. At times, however, it is useful
for routing to happen in the publisher application. Sender-Selected Routing is a RabbitMQ feature
that lets clients have extra control over routing.

The values associated with the `"CC"` and `"BCC"` header keys will be added to the routing key if they are present.
If neither of those headers is present, this extension has no effect.

### How To Use It With Bunny 0.9+

To use sender-selected distribution, set the `"CC"` and `"BCC"` headers like you would any other header:

``` ruby
x.publish("Message #{i}", :routing_key => "one", :headers => {"CC" => ["two", "three"]})
```

### Example

``` ruby
#!/usr/bin/env ruby
# encoding: utf-8

require "bunny"

puts "=> Using sender-selected distribution"
puts

conn = Bunny.new
conn.start

ch   = conn.create_channel
x    = ch.direct("bunny.examples.ssd.exchange")
q1   = ch.queue("", :exclusive => true).bind(x, :routing_key => "one")
q2   = ch.queue("", :exclusive => true).bind(x, :routing_key => "two")
q3   = ch.queue("", :exclusive => true).bind(x, :routing_key => "three")
q4   = ch.queue("", :exclusive => true).bind(x, :routing_key => "four")

10.times do |i|
  x.publish("Message #{i}", :routing_key => "one", :headers => {"CC" => ["two", "three"]})
end

sleep 0.2
puts "Queue #{q1.name} now has #{q1.message_count} messages in it"
puts "Queue #{q2.name} now has #{q2.message_count} messages in it"
puts "Queue #{q3.name} now has #{q3.message_count} messages in it"
puts "Queue #{q4.name} now has #{q4.message_count} messages in it"

sleep 0.7
puts "Closing..."
conn.close
```

### Learn More

See also rabbitmq.com section on [Sender-Selected Distribution](http://www.rabbitmq.com/sender-selected.html)

## Dead Letter Exchange (DLX)

The x-dead-letter-exchange argument to queue.declare controls the exchange to which messages from that queue are 'dead-lettered'.
A message is dead-lettered when any of the following events occur:

The message is rejected (basic.reject or basic.nack) with requeue=false; or the TTL for the message expires.

### How To Use It With Bunny 0.9+

Dead-letter Exchange is a feature that is used by specifying additional queue arguments:

 * `"x-dead-letter-exchange"` specifies the exchange that dead lettered messages should be published to by RabbitMQ
 * `"x-dead-letter-routing-key"` specifies the routing key that should be used (has to be a constant value)

``` ruby
dlx  = ch.fanout("bunny.examples.dlx.exchange")
q    = ch.queue("", :exclusive => true, :arguments => {"x-dead-letter-exchange" => dlx.name}).bind(x)
```

### Example

``` ruby
#!/usr/bin/env ruby
# encoding: utf-8

require "bunny"

puts "=> Using dead letter exchange"
puts

conn = Bunny.new
conn.start

ch   = conn.create_channel
x    = ch.fanout("amq.fanout")
dlx  = ch.fanout("bunny.examples.dlx.exchange")
q    = ch.queue("", :exclusive => true, :arguments => {"x-dead-letter-exchange" => dlx.name}).bind(x)
# dead letter queue
dlq  = ch.queue("", :exclusive => true).bind(dlx)

x.publish("")
sleep 0.2

delivery_info, _, _ = q.pop(:manual_ack => true)
puts "#{dlq.message_count} messages dead lettered so far"
puts "Rejecting a message"
ch.nack(delivery_info.delivery_tag, false)
sleep 0.2
puts "#{dlq.message_count} messages dead lettered so far"

dlx.delete
puts "Disconnecting..."
conn.close
```

### Learn More

See also rabbitmq.com section on [Dead Letter Exchange](http://www.rabbitmq.com/dlx.html)

## Wrapping Up

RabbitMQ provides a number of useful extensions to the AMQP 0.9.1 specification.

Bunny 0.9 and later releases have RabbitMQ extensions support built into the core. Some features are based on optional arguments
for queues, exchanges or messages, and some are Bunny public API features. Any future argument-based extensions are likely to be
useful with Bunny immediately, without any library modifications.

## What to Read Next

The documentation is organized as [a number of guides](/articles/guides.html), covering various topics.

We recommend that you read the following guides first, if possible, in this order:

 * [Durability and Related Matters](/articles/durability.html)
 * [Error Handling and Recovery](/articles/error_handling.html)
 * [Troubleshooting](/articles/troubleshooting.html)
 * [Using TLS (SSL) Connections](/articles/tls.html)

## Tell Us What You Think!

Please take a moment to tell us what you think about this guide [on Twitter](http://twitter.com/rubyamqp) or the [Bunny mailing list](https://groups.google.com/forum/#!forum/ruby-amqp)

Let us know what was unclear or what has not been covered. Maybe you do not like the guide style or grammar or discover spelling mistakes. Reader feedback is key to making the documentation better.
