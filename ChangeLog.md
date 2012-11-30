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
