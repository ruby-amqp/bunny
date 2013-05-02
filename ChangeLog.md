## Changes between Bunny 0.9.0.pre9 and 0.9.0.pre10

This release contains a **breaking API change**.

### Concurrency Improvements On JRuby

On JRuby, Bunny now will use `java.util.concurrent`-backed implementations
of some of the concurrency primitives. This both improves client stability
(JDK concurrency primitives has been around for 9 years and have
well-defined, documented semantics) and opens the door to solving
some tricky failure handling problems in the future.


### Explicitly Closed Sockets

Bunny now will correctly close the socket previous connection had
when recovering from network issues.


### Bunny::Exception Now Extends StandardError

`Bunny::Exception` now inherits from `StandardError` and not `Exception`.

Naked rescue like this

``` ruby
begin
  # ...
rescue => e
  # ...
end
```

catches only descendents of `StandardError`. Most people don't
know this and this is a very counter-intuitive practice, but
apparently there is code out there that can't be changed that
depends on this behavior.

This is a **breaking API change**.



## Changes between Bunny 0.9.0.pre8 and 0.9.0.pre9

### Bunny::Session#start Now Returns a Session

`Bunny::Session#start` now returns a session instead of the default channel
(which wasn't intentional, default channel is a backwards-compatibility implementation
detail).

`Bunny::Session#start` also no longer leaves dead threads behind if called multiple
times on the same connection.


### More Reliable Heartbeat Sender

Heartbeat sender no longer slips into an infinite loop if it encounters an exception.
Instead, it will just stop (and presumably re-started when the network error recovery
kicks in or the app reconnects manually).


### Network Recovery After Delay

Network reconnection now kicks in after a delay to avoid aggressive
reconnections in situations when we don't want to endlessly reconnect
(e.g. when the connection was closed via the Management UI).

The `:network_recovery_interval` option passed to `Bunny::Session#initialize` and `Bunny.new`
controls the interval. Default is 5 seconds.


### Default Heartbeat Value Is Now Server-Defined

Bunny will now use heartbeat value provided by RabbitMQ by default.



## Changes between Bunny 0.9.0.pre7 and 0.9.0.pre8

### Stability Improvements

Several stability improvements in the network
layer, connection error handling, and concurrency hazards.


### Automatic Connection Recovery Can Be Disabled

Automatic connection recovery now can be disabled by passing
the `:automatically_recover => false` option to `Bunny#initialize`).

When the recovery is disabled, network I/O-related exceptions will
cause an exception to be raised in thee thread the connection was
started on.


### No Timeout Control For Publishing

`Bunny::Exchange#publish` and `Bunny::Channel#basic_publish` no
longer perform timeout control (using the timeout module) which
roughly increases throughput for flood publishing by 350%.

Apps that need delivery guarantees should use publisher confirms.



## Changes between Bunny 0.9.0.pre6 and 0.9.0.pre7

### Bunny::Channel#on_error

`Bunny::Channel#on_error` is a new method that lets you define
handlers for channel errors that are caused by methods that have no
responses in the protocol (`basic.ack`, `basic.reject`, and `basic.nack`).

This is rarely necessary but helps make sure no error goes unnoticed.

Example:

``` ruby
channel.on_error |ch, channel_close|
  puts channel_close.inspect
end
```

### Fixed Framing of Larger Messages With Unicode Characters

Larger (over 128K) messages with non-ASCII characters are now always encoded
correctly with amq-protocol `1.2.0`.


### Efficiency Improvements

Publishing of large messages is now done more efficiently.

Contributed by Greg Brockman.


### API Reference

[Bunny API reference](http://reference.rubybunny.info) is now up online.


### Bunny::Channel#basic_publish Support For :persistent

`Bunny::Channel#basic_publish` now supports both
`:delivery_mode` and `:persistent` options.

### Bunny::Channel#nacked_set

`Bunny::Channel#nacked_set` is a counter-part to `Bunny::Channel#unacked_set`
that contains `basic.nack`-ed (rejected) delivery tags.


### Single-threaded Network Activity Mode

Passing `:threaded => false` to `Bunny.new` now will use the same
thread for publisher confirmations (may be useful for retry logic
implementation).

Contributed by Greg Brockman.


## Changes between Bunny 0.9.0.pre5 and 0.9.0.pre6

### Automatic Network Failure Recovery

Automatic Network Failure Recovery is a new Bunny feature that was earlier
impemented and vetted out in [amqp gem](http://rubyamqp.info). What it does
is, when a network activity loop detects an issue, it will try to
periodically recover [first TCP, then] AMQP 0.9.1 connection, reopen
all channels, recover all exchanges, queues, bindings and consumers
on those channels (to be clear: this only includes entities and consumers added via
Bunny).

Publishers and consumers will continue operating shortly after the network
connection recovers.

Learn more in the [Error Handling and Recovery](http://rubybunny.info/articles/error_handling.html)
documentation guide.

### Confirms Listeners

Bunny now supports listeners (callbacks) on

``` ruby
ch.confirm_select do |delivery_tag, multiple, nack|
  # handle confirms (e.g. perform retries) here
end
```

Contributed by Greg Brockman.

### Publisher Confirms Improvements

Publisher confirms implementation now uses non-strict equality (`<=`) for
cases when multiple messages are confirmed by RabbitMQ at once.

`Bunny::Channel#unconfirmed_set` is now part of the public API that lets
developers access unconfirmed delivery tags to perform retries and such.

Contributed by Greg Brockman.

### Publisher Confirms Concurrency Fix

`Bunny::Channel#wait_for_confirms` will now correctly block the calling
thread until all pending confirms are received.


## Changes between Bunny 0.9.0.pre4 and 0.9.0.pre5

### Channel Errors Reset

Channel error information is now properly reset when a channel is (re)opened.

GH issue: #83.

### Bunny::Consumer#initial Default Change

the default value of `Bunny::Consumer` noack argument changed from false to true
for consistency.

### Bunny::Session#prefetch Removed

Global prefetch is not implemented in RabbitMQ, so `Bunny::Session#prefetch`
is gone from the API.

### Queue Redeclaration Bug Fix

Fixed a problem when a queue was not declared after being deleted and redeclared

GH issue: #80

### Channel Cache Invalidation

Channel queue and exchange caches are now properly invalidated when queues and
exchanges are deleted.


## Changes between Bunny 0.9.0.pre3 and 0.9.0.pre4

### Heartbeats Support Fixes

Heartbeats are now correctly sent at safe intervals (half of the configured
interval). In addition, setting `:heartbeat => 0` (or `nil`) will disable
heartbeats, just like in Bunny 0.8 and [amqp gem](http://rubyamqp.info).

Default `:heartbeat` value is now `600` (seconds), the same as RabbitMQ 3.0
default.


### Eliminate Race Conditions When Registering Consumers

Fixes a potential race condition between `basic.consume-ok` handler and
delivery handler when a consumer is registered for a queue that has
messages in it.

GH issue: #78.

### Support for Alternative Authentication Mechanisms

Bunny now supports two authentication mechanisms and can be extended
to support more. The supported methods are `"PLAIN"` (username
and password) and `"EXTERNAL"` (typically uses TLS, UNIX sockets or
another mechanism that does not rely on username/challenge pairs).

To use the `"EXTERNAL"` method, pass `:auth_mechanism => "EXTERNAL"` to
`Bunny.new`:

``` ruby
# uses the EXTERNAL authentication mechanism
conn = Bunny.new(:auth_method => "EXTERNAL")
conn.start
```

### Bunny::Consumer#cancel

A new high-level API method: `Bunny::Consumer#cancel`, can be used to
cancel a consumer. `Bunny::Queue#subscribe` will now return consumer
instances when the `:block` option is passed in as `false`.


### Bunny::Exchange#delete Behavior Change

`Bunny::Exchange#delete` will no longer delete pre-declared exchanges
that cannot be declared by Bunny (`amq.*` and the default exchange).


### Bunny::DeliveryInfo#redelivered?

`Bunny::DeliveryInfo#redelivered?` is a new method that is an alias
to `Bunny::DeliveryInfo#redelivered` but follows the Ruby community convention
about predicate method names.

### Corrected Bunny::DeliveryInfo#delivery_tag Name

`Bunny::DeliveryInfo#delivery_tag` had a typo which is now fixed.


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
