## Changes between Bunny 0.9.0.pre3 and 0.9.0.pre4

No changes yet.


## Changes between Bunny 0.9.0.pre2 and 0.9.0.pre3

### Client Capabilities

Bunny now correctly lists RabbitMQ extensions it currently supports in client capabilities:

 * `basic.nack`
 * exchange-to-exchange bindings
 * consumer cancellation notifications
 * publisher confirms

### Publisher Confirms Support

[Lightweight Publisher Confirms](http://www.rabbitmq.com/blog/2011/02/10/introducing-publisher-confirms/) is a
RabbitMQ feature that lets publishers keep track of message routing without adding
noticeable throughput degradation as it is the case with AMQP 0.9.1 transactions.

Bunny `0.9.0.pre3` supports publisher confirms. Publisher confirms are enabled per channel,
using the `Bunny::Channel#confirm_select` method. `Bunny::Channel#wait_for_confirms` is a method
that blocks current thread until the client gets confirmations for all unconfirmed published
messages:

``` ruby
ch = connection.create_channel
ch.confirm_select

ch.using_publisher_confirmations? # => true

q  = ch.queue("", :exclusive => true)
x  = ch.default_exchange

5000.times do
  x.publish("xyzzy", :routing_key => q.name)
end

ch.next_publish_seq_no.should == 5001
ch.wait_for_confirms # waits until all 5000 published messages are acknowledged by RabbitMQ
```


### Consumers as Objects

It is now possible to register a consumer as an object instead
of a block. Consumers that are class instances support cancellation
notifications (e.g. when a queue they're registered with is deleted).

To support this, Bunny introduces two new methods: `Bunny::Channel#basic_consume_with`
and `Bunny::Queue#subscribe_with`, that operate on consumer objects. Objects are
supposed to respond to three selectors:

 * `:handle_delivery` with 3 arguments
 * `:handle_cancellation` with 1 argument
 * `:consumer_tag=` with 1 argument

An example:

``` ruby
class ExampleConsumer < Bunny::Consumer
  def cancelled?
    @cancelled
  end

  def handle_cancellation(_)
    @cancelled = true
  end
end

# "high-level" API
ch1 = connection.create_channel
q1  = ch1.queue("", :auto_delete => true)

consumer = ExampleConsumer.new(ch1, q)
q1.subscribe_with(consumer)

# "low-level" API
ch2 = connection.create_channel
q1  = ch2.queue("", :auto_delete => true)

consumer = ExampleConsumer.new(ch2, q)
ch2.basic_consume_with.(consumer)
```

### RABBITMQ_URL ENV variable support

If `RABBITMQ_URL` environment variable is set, Bunny will assume
it contains a valid amqp URI string and will use it. This is convenient
with some PaaS technologies such as Heroku.


## Changes between Bunny 0.9.0.pre1 and 0.9.0.pre2

### Change Bunny::Queue#pop default for :ack to false

It makes more sense for beginners that way.


### Bunny::Queue#subscribe now support the new :block option

`Bunny::Queue#subscribe` support the new `:block` option
(a boolean).
    
It controls whether the current thread will be blocked
by `Bunny::Queue#subscribe`.


### Bunny::Exchange#publish now supports :key again

`Bunny::Exchange#publish` now supports `:key` as an alias for
`:routing_key`.


### Bunny::Session#queue et al.

`Bunny::Session#queue`, `Bunny::Session#direct`, `Bunny::Session#fanout`, `Bunny::Session#topic`,
and `Bunny::Session#headers` were added to simplify migration. They all delegate to their respective
`Bunny::Channel` methods on the default channel every connection has.


### Bunny::Channel#exchange, Bunny::Session#exchange

`Bunny::Channel#exchange` and `Bunny::Session#exchange` were added to simplify
migration:

``` ruby
b = Bunny.new
b.start

# uses default connection channel
x = b.exchange("logs.events", :topic)
```

### Bunny::Queue#subscribe now properly takes 3 arguments

``` ruby
q.subscribe(:exclusive => false, :ack => false) do |delivery_info, properties, payload|
  # ...
end
```



## Changes between Bunny 0.8.x and 0.9.0.pre1

### New convenience functions: Bunny::Channel#fanout, Bunny::Channel#topic

`Bunny::Channel#fanout`, `Bunny::Channel#topic`, `Bunny::Channel#direct`, `Bunny::Channel#headers`,
and`Bunny::Channel#default_exchange` are new convenience methods to instantiate exchanges:

``` ruby
conn = Bunny.new
conn.start

ch = conn.create_channel
x  = ch.fanout("logging.events", :durable => true)
```


### Bunny::Queue#pop and consumer handlers (Bunny::Queue#subscribe) signatures have changed

Bunny `< 0.9.x` example:

``` ruby
h = queue.pop

puts h[:delivery_info], h[:header], h[:payload]
```

Bunny `>= 0.9.x` example:

``` ruby
delivery_info, properties, payload = queue.pop
```

The improve is both in that Ruby has positional destructuring, e.g.

``` ruby
delivery_info, _, content = q.pop
```

but not hash destructuring, like, say, Clojure does.

In addition we return nil for content when it should be nil
(basic.get-empty) and unify these arguments betwee

 * Bunny::Queue#pop

 * Consumer (Bunny::Queue#subscribe, etc) handlers

 * Returned message handlers

The unification moment was the driving factor.



### Bunny::Client#write now raises Bunny::ConnectionError

Bunny::Client#write now raises `Bunny::ConnectionError` instead of `Bunny::ServerDownError` when network
I/O operations fail.


### Bunny::Client.create_channel now uses a bitset-based allocator

Instead of reusing channel instances, `Bunny::Client.create_channel` now opens new channels and
uses bitset-based allocator to keep track of used channel ids. This avoids situations when
channels are reused or shared without developer's explicit intent but also work well for
long running applications that aggressively open and release channels.

This is also how amqp gem and RabbitMQ Java client manage channel ids.


### Bunny::ServerDownError is now Bunny::TCPConnectionFailed

`Bunny::ServerDownError` is now an alias for `Bunny::TCPConnectionFailed`
