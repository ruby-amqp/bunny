## Changes between Bunny 2.7.1 and 2.7.2 (unreleased)

No changes yet.


## Changes between Bunny 2.7.0 and 2.7.1 (Sep 25th, 2017)

### Sensible Socket Read Timeouts When RabbitMQ is Configured to Disabled Heartbeats

Bunny now correctly handles scenarios where server is configured
to disable heartbeats (which is a terrible idea, don't do it!)

GitHub issue: [#519](https://github.com/ruby-amqp/bunny/issues/519).

### Bunny::Channel#basic_get Usability

`Bunny::Channel#basic_get` invoked with a non-existent queue now
throws a channel exception instead of a generic operation timeout.

GitHub issue: [#518](https://github.com/ruby-amqp/bunny/issues/518).

### Spec Suite Improvements

`BUNNY_CERTIFICATE_DIR` environment variable now can be used
to override local CA and client certificate/key pair directory.
The directory is expected to be the result directory generated
by the basic [tls-gen](http://github.com/michaelklishin/tls-gen) profile.

TLSv1.0 is no longer used in tests because it's being disabled by default
by more and more installations as it has known vulnerabilities
and is no longer considered to be acceptable by several compliance
standards (e.g. PCI DSS).

### Improved Synchronisation for channel.close Handlers

`channel.close` handler will now acquire a lock . This avoids concurrency
hazards in some rare scenarios when a channel is closed due a protocol
exception by the server and concurrently opened by user code
at the same time.

### More Meaningful Error Messages in Bunny::Session#create_channel

Sometimes users attempt to open a channel on a connection that
isn't connected yet because `Bunny::Session#start` was never invoked.

`Bunny::Session#create_channel` will now provide a more sensible exception message
in those cases.


## Changes between Bunny 2.6.0 and 2.7.0 (May 11th, 2017)

### amq-protocol Update

Minimum `amq-protocol` version is now [`2.2.0`]](https://github.com/ruby-amqp/amq-protocol/blob/master/ChangeLog.md#changes-between-210-and-220-may-11th-2017) which includes
a change in [how timestamps are encoded](https://github.com/ruby-amqp/amq-protocol/issues/64).


### `Bunny::ContinuationQueue#poll` Less Prone to Race Conditions

`Bunny::ContinuationQueue#poll` was reworked with feedback from Joseph Wong.

GitHub issue: [#462](https://github.com/ruby-amqp/bunny/issues/462)


### Recovery Attempt Counting Strategy Changed

Previous behehavior is not unreasonable but is not what many users and
even RabbitMQ team members come to expect. Therefore it can be
considered a bug.

Previously a reconnection counter was preserved between successful
recoveries. This made the integration test that uses server-sent
connection.close possible.

With this change, the counter is reset after successful reconnection
but there's an option to go back to the original behavior. We also do
a hell of a lot more logging.

GitHub issue: [#408](https://github.com/ruby-amqp/bunny/issues/408)


### Absolute Windows File Paths are No Longer treated as Inline Certs

Contributed by Jared Smartt.

GitHub issue: [#492](https://github.com/ruby-amqp/bunny/issues/492).


### Opening a Channel on an Intentionally Closed Connection Immediately Raises an Exception

Contributed by Alessandro Verlato.

GitHub issue: [#465](https://github.com/ruby-amqp/bunny/issues/465)


### Bunny::ConsumerWorkPool#shutdown Terminates Early When It's Safe to Do So

`Bunny::ConsumerWorkPool#shutdown(true)` waited for consumer shutdown
even if the pool wasn't active (there were no consumers on its
channel).

GitHub issue: [#438](https://github.com/ruby-amqp/bunny/issues/438).


### Retry on new Ruby 2.1+ variations of `EAGAIN`, `EWOULDBLOCK`

GitHub issue: [#456](https://github.com/ruby-amqp/bunny/issues/456)


### Do Not Modify Host Arrays

Bunny now can work with frozen host arrays.

GitHub issue: [#446](https://github.com/ruby-amqp/bunny/issues/446)



## Changes between Bunny 2.5.0 and 2.6.0 (October 15th, 2016)

### Graceful Shutdown of Consumers

Consumer work pool will now allow for a grace period before stopping
pool threads so that delivery processing in progress can have a chance to finish.

GitHub issue: [#437](https://github.com/ruby-amqp/bunny/pull/437)

Contributed by Stefan Sedich.

### `Bunny::Channel#wait_for_confirms` Now Throws When Used on a Closed Channel

GitHub issue: [#428](https://github.com/ruby-amqp/bunny/pull/428)

Contributed by Dimitar Dimitrov.

### Race Condition Eliminated in `Bunny::Channel#wait_for_confirms`

GitHub issue: [#424](https://github.com/ruby-amqp/bunny/issues/424)

Contributed by Dimitar Dimitrov.

### More Defensive Consumer Work Pool

`Bunny::ConsumerWorkPool#join` and `Bunny::ConsumerWorkPool#pause`
no longer fails with a `NoMethodError` on nil when executed
on a work pool that doesn't have active threads (consumers).

This change is largely cosmetic and won't affect the majority
of of projects in any way.


## Changes between Bunny 2.4.0 and 2.5.0 (July 20th, 2016)

### Exchange Bindings are Now Correctly Recovered

GitHub issue: [#410](https://github.com/ruby-amqp/bunny/issues/410)

Contributed by Andrew Bruce.


### `Bunny::Channel#wait_for_confirms` Awaits While There're Outstanding Unconfirmed Messages

GitHub issue: [#424](https://github.com/ruby-amqp/bunny/issues/424)

Contributed by Dimitar Dimitrov.


### Queue Recovery Respects the `:no_declare` Option

Queue recovery now respects the `:no_declare` option.


### `Bunny::Channel#wait_for_confirms` Throws Early

`Bunny::Channel#wait_for_confirms` now throws an exception
early when invoked on a closed channel.

GitHub issue: [#428](https://github.com/ruby-amqp/bunny/pull/428).

Contributed by Dimitar Dimitrov.



## Changes between Bunny 2.3.0 and 2.4.0 (June 11th, 2016)

**This release includes minor breaking API changes**.

### Unconfirmed Delivery Tag Set Reset on Network Recovery

Channels will now reset their unconfirmed delivery tag set after
recovery.

GitHub issue: [#406](https://github.com/ruby-amqp/bunny/pull/406)

Contributed by Bill Ruddock.

### Support (Quoted) IPv6 Addresses in Address Lists

GitHub issue: [#383](https://github.com/ruby-amqp/bunny/issues/383).

Contributed by Jeremy Heiler.

### Transport#read_fully Doesn't Try to Recover

Since transport is replaced by a recovering connection
anyway, and this produces confusing errors up the stack.

GitHub issue: [#359](https://github.com/ruby-amqp/bunny/issues/359)

Contributed by Donal McBreen.

### Client-Provided Session `:properties` Merged with Defaults

Client-Provided Session `:properties` will now be merged with defaults
instead of replacing them. This makes it much more convenient to
override a single key.

### More Predictable RABBITMQ_URL Handling

**This is a breaking API change**.

`RABBITMQ_URL` no longer will be used if any other
connection options are provided. This makes it possible
to use `RABBITMQ_URL` for some connections and options
for others in a single OS process.

GitHub issue: [#403](https://github.com/ruby-amqp/bunny/pull/403)

Contributed by Jimmy Petersen.


## Changes between Bunny 2.2.0 and 2.3.0 (Feb 26th, 2016)

### Thread#abort_on_exception Setting for Consumer Work Pool Threads

`Bunny::Session#create_channel` now supports a 3rd argument that,
when set to `true`, makes consumer work pool threads to have
`Thread#abort_on_exception` set on them.

GH issue: [#382](https://github.com/ruby-amqp/bunny/pull/382)

Contributed by Seamus Abshere.

### Explicit Transport Closure on Recovery

Bunny now will explicitly close previosly used transport before starting
connection recovery.

GitHub issue: [#377](https://github.com/ruby-amqp/bunny/pull/377).

Contributed by bkanhoopla.

### No TLS Socket Double-init

Makes sure that TLS sockets are not double-initialized.

GH issue: [#345](https://github.com/ruby-amqp/bunny/issues/345).

Contributed by Carl Hörberg.

### Lazily Evaluated Debug Log Strings

GH issue: [#375](https://github.com/ruby-amqp/bunny/pull/375)

Contributed by Omer Katz.



## Changes between Bunny 2.1.0 and 2.2.0 (Sep 6th, 2015)

### Add :addresses to connect options

Before this the connection options only allowed multiple hosts, an
address is a combination of a host and a port. This makes it possible to
specify different hosts with different ports.

Contributed by Bart van Zon (Tele2).

### Recover from connection.close by default

Bunny will now try to reconnect also when server sent connection.close is
received, e.g. when a server is restarting (but also when the connection is
force closed by the server). This is in-line with how many other clients behave.
The old default was `recover_from_connection_close: false`.

Contributed by Carl Hörberg (CloudAMQP).


## Changes between Bunny 2.0.0 and 2.1.0

Bunny 2.1.0 has an **important breaking change**. It is highly
advised that 2.1.0 is not mixed with earlier versions of Bunny
in case your applications include **integers in message headers**.

### Integer Value Serialisation in Headers

Integer values in headers are now serialised as signed 64-bit integers. Previously
they were serialised as 32-bit unsigned integers, causing both underflows
and overflows: incorrect values were observed by consumers.

It is highly
advised that 2.1.0 is not mixed with earlier versions of Bunny
in case your applications include integers in message headers.

If that's not the case, Bunny 2.1 will integeroperate with any earlier version
starting with 0.9.0 just fine. Popular clients in other languages
(e.g. Java and .NET) will interoperate with Bunny 2.1.0 without
issues.


### Explicit Ruby 2.0 Requirement

Bunny now requires Ruby 2.0 in the gemspec.

Contributed by Carl Hörberg.

### JRuby Fix

Bunny runs again on JRuby. Note that
JRuby users are strongly advised to use March Hare instead.

Contributed by Teodor Pripoae.



## Changes between Bunny 1.7.0 and 2.0.0

Bunny `2.0` doesn't have any breaking API changes
but drops Ruby 1.8 and 1.9 (both EOL'ed) support,
hence the version.

### Minimum Required Ruby Version is 2.0

Bunny `2.0` requires Ruby 2.0 or later.

## Non-Blocking Writes

Bunny now uses non-blocking socket writes, uses a reduced
number of writes for message publishing (frames are batched
into a single write), and handles TCP back pressure from
RabbitMQ better.

Contributed by Irina Bednova and Michael Klishin.

### Reduced Timeout Use

`Bunny::ContinuationQueue#poll` no longer relies on Ruby's `Timeout` which has
numerous issues, including starting a new "interruptor" thread per operation,
which is far from efficient.

Contributed by Joe Eli McIlvain and Carl Hörberg.

### Capped Number of Connection Recovery Attempts

`:recovery_attempts` is a new option that limits the number of
connection recovery attempts performed by Bunny. `nil` means
"no limit".

Contributed by Irina Bednova.

### Bunny::Channel#basic_ack and Related Methods Improvements

`Bunny::Channel#basic_ack`, `Bunny::Channel#basic_nack`, and `Bunny::Channel#basic_reject`
now adjust delivery tags between connection recoveries, as well as have a default value for
the second argument.

Contributed by Wayne Conrad.

### Logger Output Remains Consistent

Setting the `@logger.progname` attribute changes the output of the logger.
This is not expected behaviour when the client provides a custom logger.
Behaviour remains unchainged when the internally initialized logger is used.

Contributed by Justin Carter.

### prefetch_count is Limited to 65535

Since `basic.qos`'s `prefetch_count` field is of type `short` in the protocol,
Bunny must enforce its maximum allowed value to `2^16 - 1` to avoid
confusing issues due to overflow.

### Per-Consumer and Per-Channel Prefetch

Recent RabbitMQ versions support `basic.qos` `global` flag, controlling whether
`prefetch` applies per-consumer or per-channel. Bunny `Channel#prefetch` now
allows flag to be set as optional parameter, with the same default behaviour as
before (per-consumer).

Contributed by tiredpixel.


## Changes between Bunny 1.6.0 and 1.7.0

### TLS Peer Verification Enabled by Default

When using TLS, peer verification is now enabled by default.
It is still possible to [disable verification](http://rubybunny.info/articles/tls.html), e.g. for convenient
development locally.

Peer verification is a means of protection against man-in-the-middle attacks
and is highly recommended in production settings. However, it can be an inconvenience
during local development. We believe it's time to have the default to be
more secure.

Contributed by Michael Klishin (Pivotal) and Andre Foeken (Nedap).


### Higher Default Connection Timeout

Default connection timeout has been increased to 25 seconds. The older
default of 5 seconds wasn't sufficient in some edge cases with DNS
resolution (e.g. when primary DNS server is down).

The value can be overriden at connection time.

Contributed by Yury Batenko.


### Socket Read Timeout No Longer Set to 0 With Disabled Heartbeats

GH issue: [#267](https://github.com/ruby-amqp/bunny/pull/267).


### JRuby Writes Fixes

On JRuby, Bunny reverts back to using plain old `write(2)` for writes. The CRuby implementation
on JRuby suffers from I/O incompatibilities. Until JRuby

Bunny users who run on JRuby are highly recommended to switch to [March Hare](http://rubymarchhare.info),
which has nearly identical API and is significantly more efficient.


### Bunny::Session#with_channel Synchornisation Improvements

`Bunny::Session#with_channel` is now fully synchronised and won't run into `COMMAND_INVALID` errors
when used from multiple threads that share a connection.



## Changes between Bunny 1.5.0 and 1.6.0

### TLSv1 by Default

TLS connections now prefer TLSv1 (or later, if available) due to the recently discovered
[POODLE attack](https://www.openssl.org/~bodo/ssl-poodle.pdf) on SSLv3.

Contributed by Michael Klishin (Pivotal) and Justin Powers (Desk.com).

GH issues:

 * [#259](https://github.com/ruby-amqp/bunny/pull/259)
 * [#260](https://github.com/ruby-amqp/bunny/pull/260)
 * [#261](https://github.com/ruby-amqp/bunny/pull/261)


### Socket Read and Write Timeout Improvements

Bunny now sets a read timeout on the sockets it opens, and uses
`IO.select` timeouts as the most reliable option available
on Ruby 1.9 and later.

GH issue: [#254](https://github.com/ruby-amqp/bunny/pull/254).

Contributed by Andre Foeken (Nedap).

### Inline TLS Certificates Support

TLS certificate options now accept inline certificates as well as
file paths.

GH issues: [#255](https://github.com/ruby-amqp/bunny/pull/255), [#256](https://github.com/ruby-amqp/bunny/pull/256).

Contributed by Will Barrett (Sqwiggle).


## Changes between Bunny 1.4.0 and 1.5.0

### Improved Uncaught Exception Handler

Uncaught exception handler now provides more information about the exception,
including its caller (one more stack trace line).

Contributed by Carl Hörberg (CloudAMQP).


### Convenience Method for Temporary (Server-named, Exclusive) Queue Declaration

`Bunny::Channel#temporary_queue` is a convenience method that declares a new
server-named exclusive queue:

``` ruby
q = ch.temporary_queue
```

Contributed by Daniel Schierbeck (Zendesk).

### Recovery Reliability Improvements

Automatic connection recovery robustness improvements.
Contributed by Andre Foeken (Nedap).

### Host Lists

It is now possible to pass the `:hosts` option to `Bunny.new`/`Bunny::Session#initialize`.
When connection to RabbitMQ (including during connection recovery), a random host
will be chosen from the list.

Connection shuffling and robustness improvements.

Contributed by Andre Foeken (Nedap).

### Default Channel Removed

Breaks compatibility with Bunny 0.8.x.

`Bunny:Session#default_channel` was removed. Please open channels explicitly now,
as all the examples in the docs do.


## Changes between Bunny 1.3.0 and 1.4.0

### Channel#wait_for_confirms Returns Immediately If All Publishes Confirmed

Contributed by Matt Campbell.

### Publisher Confirms is In Sync After Recovery

When a connection is recovered, the sequence counter resets on the
broker, but not the client. To keep things in sync the client must store a confirmation
offset after a recovery.

Contributed by Devin Christensen.

### NoMethodError on Thread During Shutdown

During abnormal termination, `Bunny::Session#close` no longer tries
to call the non-existent `terminate_with` method on its origin
thread.


## Changes between Bunny 1.2.0 and 1.3.0

### TLS Can Be Explicitly Disabled

TLS now can be explicitly disabled even when connecting (without TLS)
to the default RabbitMQ TLS/amqps port (5671):

``` ruby
conn = Bunny.new(:port => 5671, :tls => false)
```

Contributed by Muhan Zou.


### Single Threaded Connections Raise Shutdown Exceptions

Single threaded Bunny connections will now raise exceptions
that occur during shutdown as is (instead of trying to shut down
I/O loop which only threaded ones have).

Contributed by Carl Hörberg.


### Synchronization Improvements for Session#close

`Bunny::Session#close` now better synchronizes state transitions,
eliminating a few race condition scenarios with I/O reader thread.


### Bunny::Exchange.default Fix

`Bunny::Exchange.default` no longer raises an exception.

Note that it is a legacy compatibility method. Please use
`Bunny::Channel#default_exchange` instead.

Contributed by Justin Litchfield.

GH issue [#211](https://github.com/ruby-amqp/bunny/pull/211).

### Bunny::Queue#pop_as_hash Removed

`Bunny::Queue#pop_as_hash`, which was added to ease migration
to Bunny 0.9, was removed.

### Bunny::Queue#pop Wraps Metadata

`Bunny::Queue#pop` now wraps `basic.get-ok` and message properties
into `Bunny::GetResponse` and `Bunny::MessageProperties`, just like
`basic.consume` deliveries.

GH issue: [#212](https://github.com/ruby-amqp/bunny/issues/212).

### Better Synchronization for Publisher Confirms

Publisher confirms implementation now synchronizes unconfirmed
set better.

Contributed by Nicolas Viennot.

### Channel Allocation After Recovery

Channel id allocator is no longer reset after recovery
if there are channels open. Makes it possible to open channels
on a recovered connection (in addition to the channels
it already had).



## Changes between Bunny 1.1.0 and 1.2.0

### :key Supported in Bunny::Channel#queue_bind

It is now possible to use `:key` (which Bunny versions prior to 0.9 used)
as well as `:routing_key` as an argument to `Bunny::Queue#bind`.

### System Exceptions Not Rescued by the Library

Bunny now rescues `StandardError` instead of `Exception` where
it automatically does so (e.g. when dispatching deliveries to consumers).

Contributed by Alex Young.


### Initial Socket Connection Timeout Again Raises Bunny::TCPConnectionFailed

Initial socket connection timeout again raises `Bunny::TCPConnectionFailed`
on the connection origin thread.

### Thread Leaks Plugged

`Bunny::Session#close` on connections that have experienced a network failure
will correctly clean up I/O and heartbeat sender threads.

Contributed by m-o-e.

### Bunny::Concurrent::ContinuationQueue#poll Rounding Fix

`Bunny::Concurrent::ContinuationQueue#poll` no longer floors the argument
to the nearest second.

Contributed by Brian Abreu.

### Routing Key Limit

Per AMQP 0-9-1 spec, routing keys cannot be longer than 255 characters.
`Bunny::Channel#basic_publish` and `Bunny::Exchange#publish` now enforces
this limit.

### Nagle's Algorithm Disabled Correctly

Bunny now properly disables [Nagle's algorithm](http://boundary.com/blog/2012/05/02/know-a-delay-nagles-algorithm-and-you/)
on the sockets it opens. This likely means
significantly lower latency for workloads that involve
sending a lot of small messages very frequently.

[Contributed](https://github.com/ruby-amqp/bunny/pull/187) by Nelson Gauthier (AirBnB).

### Internal Exchanges

Exchanges now can be declared as internal:

``` ruby
ch = conn.create_channel
x  = ch.fanout("bunny.tests.exchanges.internal", :internal => true)
```

Internal exchanges cannot be published to by clients and are solely used
for [Exchange-to-Exchange bindings](http://rabbitmq.com/e2e.html) and various
plugins but apps may still need to bind them. Now it is possible
to do so with Bunny.

### Uncaught Consumer Exceptions

Uncaught consumer exceptions are now handled by uncaught exceptions
handler that can be defined per channel:

``` ruby
ch.on_uncaught_exception do |e, consumer|
  # ...
end
```



## Changes between Bunny 1.1.0.rc1 and 1.1.0

### Synchronized Session#create_channel and Session#close_channel

Full bodies of `Bunny::Session#create_channel` and `Bunny::Session#close_channel`
are now synchronized, which makes sure concurrent `channel.open` and subsequent
operations (e.g. `exchange.declare`) do not result in connection-level exceptions
(incorrect connection state transitions).

### Corrected Recovery Log Message

Bunny will now use actual recovery interval in the log.

Contributed by Chad Fowler.




## Changes between Bunny 1.1.0.pre2 and 1.1.0.rc1

### Full Channel State Recovery

Channel recovery now involves recovery of publisher confirms and
transaction modes.


### TLS	Without Peer Verification

Bunny now successfully performs	TLS upgrade when peer verification
is disabled.

Contributed by Jordan Curzon.

### Bunny::Session#with_channel Ensures the Channel is Closed

`Bunny::Session#with_channel` now makes sure the channel is closed
even if provided block raises an exception

Contributed by Carl Hoerberg.



### Channel Number = 0 is Rejected

`Bunny::Session#create_channel` will now reject channel number 0.


### Single Threaded Mode Fixes

Single threaded mode no longer fails with

```
undefined method `event_loop'
```



## Changes between Bunny 1.1.0.pre1 and 1.1.0.pre2

### connection.tune.channel_max No Longer Overflows

`connection.tune.channel_max` could previously be configured to values
greater than 2^16 - 1 (65535). This would result in a silent overflow
during serialization. The issue was harmless in practice but is still
a bug that can be quite confusing.

Bunny now caps max number of channels to 65535. This allows it to be
forward compatible with future RabbitMQ versions that may allow limiting
total # of open channels via server configuration.

### amq-protocol Update

Minimum `amq-protocol` version is now `1.9.0` which includes
bug fixes and performance improvements for channel ID allocator.

### Thread Leaks Fixes

Bunny will now correctly release heartbeat sender when allocating
a new one (usually happens only when connection recovers from a network
failure).


## Changes between Bunny 1.0.0 and 1.1.0.pre1

### Versioned Delivery Tag Fix

Versioned delivery tag now ensures all the arguments it operates
(original delivery tag, atomic fixnum instances, etc) are coerced to `Integer`
before comparison.

GitHub issues: #171.

### User-Provided Loggers

Bunny now can use any logger that provides the same API as Ruby standard library's `Logger`:

``` ruby
require "logger"
require "stringio"

io = StringIO.new
# will log to `io`
Bunny.new(:logger => Logger.new(io))
```

### Default CA's Paths Are Disabled on JRuby

Bunny uses OpenSSL provided CA certificate paths. This
caused problems on some platforms on JRuby (see [jruby/jruby#155](https://github.com/jruby/jruby/issues/1055)).

To avoid these issues, Bunny no longer uses default CA certificate paths on JRuby
(there are no changes for other Rubies), so it's necessary to provide
CA certificate explicitly.

### Fixes CPU Burn on JRuby

Bunny now uses slightly different ways of continuously reading from the socket
on CRuby and JRuby, to prevent abnormally high CPU usage on JRuby after a
certain period of time (the frequency of `EWOULDBLOCK` being raised spiked
sharply).



## Changes between Bunny 1.0.0.rc2 and 1.0.0.rc3

### [Authentication Failure Notification](http://www.rabbitmq.com/auth-notification.html) Support

`Bunny::AuthenticationFailureError` is a new auth failure exception
that subclasses `Bunny::PossibleAuthenticationFailureError` for
backwards compatibility.

As such, `Bunny::PossibleAuthenticationFailureError`'s error message
has changed.

This extension is available in RabbitMQ 3.2+.


### Bunny::Session#exchange_exists?

`Bunny::Session#exchange_exists?` is a new predicate that makes it
easier to check if a exchange exists.

It uses a one-off channel and `exchange.declare` with `passive` set to true
under the hood.

### Bunny::Session#queue_exists?

`Bunny::Session#queue_exists?` is a new predicate that makes it
easier to check if a queue exists.

It uses a one-off channel and `queue.declare` with `passive` set to true
under the hood.


### Inline TLS Certificates and Keys

It is now possible to provide inline client
certificate and private key (as strings) instead
of filesystem paths. The options are the same:

 * `:tls` which, when set to `true`, will set SSL context up and switch to TLS port (5671)
 * `:tls_cert` which now can be a client certificate (public key) in PEM format
 * `:tls_key` which now can be a client key (private key) in PEM format
 * `:tls_ca_certificates` which is an array of string paths to CA certificates in PEM format

For example:

``` ruby
conn = Bunny.new(:tls                   => true,
                 :tls_cert              => ENV["TLS_CERTIFICATE"],
                 :tls_key               => ENV["TLS_PRIVATE_KEY"],
                 :tls_ca_certificates   => ["./examples/tls/cacert.pem"])
```



## Changes between Bunny 1.0.0.rc1 and 1.0.0.rc2

### Ruby 1.8.7 Compatibility Fixes

Ruby 1.8.7 compatibility fixes around timeouts.



## Changes between Bunny 1.0.0.pre6 and 1.0.0.rc1

### amq-protocol Update

Minimum `amq-protocol` version is now `1.8.0` which includes
a bug fix for messages exactly 128 Kb in size.


### Add timeout Bunny::ConsumerWorkPool#join

`Bunny::ConsumerWorkPool#join` now accepts an optional
timeout argument.


## Changes between Bunny 1.0.0.pre5 and 1.0.0.pre6

### Respect RABBITMQ_URL value

`RABBITMQ_URL` env variable will now have effect even if
Bunny.new is invoked without arguments.



## Changes between Bunny 1.0.0.pre4 and 1.0.0.pre5

### Ruby 1.8 Compatibility

Bunny is Ruby 1.8-compatible again and no longer references
`RUBY_ENGINE`.

### Bunny::Session.parse_uri

`Bunny::Session.parse_uri` is a new method that parses
connection URIs into hashes that `Bunny::Session#initialize`
accepts.

``` ruby
Bunny::Session.parse_uri("amqp://user:pwd@broker.eng.megacorp.local/myapp_qa")
```

### Default Paths for TLS/SSL CA's on All OS'es

Bunny now uses OpenSSL to detect default TLS/SSL CA's paths, extending
this feature to OS'es other than Linux.

Contributed by Jingwen Owen Ou.


## Changes between Bunny 1.0.0.pre3 and 1.0.0.pre4

### Default Paths for TLS/SSL CA's on Linux

Bunny now will use the following TLS/SSL CA's paths on Linux by default:

 * `/etc/ssl/certs/ca-certificates.crt` on Ubuntu/Debian
 * `/etc/ssl/certs/ca-bundle.crt` on Amazon Linux
 * `/etc/ssl/ca-bundle.pem` on OpenSUSE
 * `/etc/pki/tls/certs/ca-bundle.crt` on Fedora/RHEL

and will log a warning if no CA files are available via default paths
or `:tls_ca_certificates`.

Contributed by Carl Hörberg.

### Consumers Can Be Re-Registered From Bunny::Consumer#handle_cancellation

It is now possible to re-register a consumer (and use any other synchronous methods)
from `Bunny::Consumer#handle_cancellation`, which is now invoked in the channel's
thread pool.


### Bunny::Session#close Fixed for Single Threaded Connections

`Bunny::Session#close` with single threaded connections no longer fails
with a nil pointer exception.



## Changes between Bunny 1.0.0.pre2 and 1.0.0.pre3

This release has **breaking API changes**.

### Safe[r] basic.ack, basic.nack and basic.reject implementation

Previously if a channel was recovered (reopened) by automatic connection
recovery before a message was acknowledged or rejected, it would cause
any operation on the channel that uses delivery tags to fail and
cause the channel to be closed.

To avoid this issue, every channel keeps a counter of how many times
it has been reopened and marks delivery tags with them. Using a stale
tag to ack or reject a message will produce no method sent to RabbitMQ.
Note that unacknowledged messages will be requeued by RabbitMQ when connection
goes down anyway.

This involves an API change: `Bunny::DeliveryMetadata#delivery_tag` is now
and instance of a class that responds to `#tag` and `#to_i` and is accepted
by `Bunny::Channel#ack` and related methods.

Integers are still accepted by the same methods.


## Changes between Bunny 1.0.0.pre1 and 1.0.0.pre2

### Exclusivity Violation for Consumers Now Raises a Reasonable Exception

When a second consumer is registered for the same queue on different channels,
a reasonable exception (`Bunny::AccessRefused`) will be raised.


### Reentrant Mutex Implementation

Bunny now allows mutex impl to be configurable, uses reentrant Monitor
by default.

Non-reentrant mutexes is a major PITA and may affect code that
uses Bunny.

Avg. publishing throughput with Monitor drops slightly from
5.73 Khz to 5.49 Khz (about 4% decrease), which is reasonable
for Bunny.

Apps that need these 4% can configure what mutex implementation
is used on per-connection basis.

### Eliminated Race Condition in Bunny::Session#close

`Bunny::Session#close` had a race condition that caused (non-deterministic)
exceptions when connection transport was closed before connection
reader loop was guaranteed to have stopped.

### connection.close Raises Exceptions on Connection Thread

Connection-level exceptions (including when a connection is closed via
management UI or `rabbitmqctl`) will now be raised on the connection
thread so they

 * can be handled by applications
 * do not start connection recovery, which may be uncalled for

### Client TLS Certificates are Optional

Bunny will no longer require client TLS certificates. Note that CA certificate
list is still necessary.

If RabbitMQ TLS configuration requires peer verification, client certificate
and private key are mandatory.


## Changes between Bunny 0.9.0 and 1.0.0.pre1

### Publishing Over Closed Connections

Publishing a message over a closed connection (during a network outage, before the connection
is open) will now correctly result in an exception.

Contributed by Matt Campbell.


### Reliability Improvement in Automatic Network Failure Recovery

Bunny now ensures a new connection transport (socket) is initialized
before any recovery is attempted.


### Reliability Improvement in Bunny::Session#create_channel

`Bunny::Session#create_channel` now uses two separate mutexes to avoid
a (very rare) issue when the previous implementation would try to
re-acquire the same mutex and fail (Ruby mutexes are non-reentrant).



## Changes between Bunny 0.9.0.rc1 and 0.9.0.rc2

### Channel Now Properly Restarts Consumer Pool

In a case when all consumers are cancelled, `Bunny::Channel`
will shut down its consumer delivery thread pool.

It will also now mark the pool as not running so that it can be
started again successfully if new consumers are registered later.

GH issue: #133.


### Bunny::Queue#pop_waiting is Removed

A little bit of background: on MRI, the method raised `ThreadErrors`
reliably. On JRuby, we used a different [internal] queue implementation
from JDK so it wasn't an issue.

`Timeout.timeout` uses `Thread#kill` and `Thread#join`, both of which
eventually attempt to acquire a mutex used by Queue#pop, which Bunny
currently uses for continuations. The mutex is already has an owner
and so a ThreadError is raised.

This is not a problem on JRuby because there we don't use Ruby's
Timeout and Queue and instead rely on a JDK concurrency primitive
which provides "poll with a timeout".

[The issue with `Thread#kill` and `Thread#raise`](http://blog.headius.com/2008/02/ruby-threadraise-threadkill-timeoutrb.html)
has been first investigated and blogged about by Ruby implementers
in 2008.

Finding a workaround will probably take a bit of time and may involve
reimplementing standard library and core classes.

We don't want this issue to block Bunny 0.9 release. Neither we want
to ship a broken feature.  So as a result, we will drop
Bunny::Queue#pop_waiting since it cannot be reliably implemented in a
reasonable amount of time on MRI.

Per issue #131.


### More Flexible SSLContext Configuration

Bunny will now upgrade connection to SSL in `Bunny::Session#start`,
so it is possible to fine tune SSLContext and socket settings
before that:

``` ruby
require "bunny"

conn = Bunny.new(:tls                   => true,
                 :tls_cert              => "examples/tls/client_cert.pem",
                 :tls_key               => "examples/tls/client_key.pem",
                 :tls_ca_certificates   => ["./examples/tls/cacert.pem"])

puts conn.transport.socket.inspect
puts conn.transport.tls_context.inspect
```

This also means that `Bunny.new` will now open the socket. Previously
it was only done when `Bunny::Session#start` was invoked.


## Changes between Bunny 0.9.0.pre13 and 0.9.0.rc1

### TLS Support

Bunny 0.9 finally supports TLS. There are 3 new options `Bunny.new` takes:

 * `:tls` which, when set to `true`, will set SSL context up and switch to TLS port (5671)
 * `:tls_cert` which is a string path to the client certificate (public key) in PEM format
 * `:tls_key` which is a string path to the client key (private key) in PEM format
 * `:tls_ca_certificates` which is an array of string paths to CA certificates in PEM format

An example:

``` ruby
conn = Bunny.new(:tls                   => true,
                 :tls_cert              => "examples/tls/client_cert.pem",
                 :tls_key               => "examples/tls/client_key.pem",
                 :tls_ca_certificates   => ["./examples/tls/cacert.pem"])
```


### Bunny::Queue#pop_waiting

**This function was removed in v0.9.0.rc2**

`Bunny::Queue#pop_waiting` is a new function that mimics `Bunny::Queue#pop`
but will wait until a message is available. It uses a `:timeout` option and will
raise an exception if the timeout is hit:

``` ruby
# given 1 message in the queue,
# works exactly as Bunny::Queue#get
q.pop_waiting

# given no messages in the queue, will wait for up to 0.5 seconds
# for a message to become available. Raises an exception if the timeout
# is hit
q.pop_waiting(:timeout => 0.5)
```

This method only makes sense for collecting Request/Reply ("RPC") replies.


### Bunny::InvalidCommand is now Bunny::CommandInvalid

`Bunny::InvalidCommand` is now `Bunny::CommandInvalid` (follows
the exception class naming convention based on response status
name).



## Changes between Bunny 0.9.0.pre12 and 0.9.0.pre13

### Channels Without Consumers Now Tear Down Consumer Pools

Channels without consumers left (when all consumers were cancelled)
will now tear down their consumer work thread pools, thus making
`HotBunnies::Queue#subscribe(:block => true)` calls unblock.

This is typically the desired behavior.

### Consumer and Channel Available In Delivery Handlers

Delivery handlers registered via `Bunny::Queue#subscribe` now will have
access to the consumer and channel they are associated with via the
`delivery_info` argument:

``` ruby
q.subscribe do |delivery_info, properties, payload|
  delivery_info.consumer # => the consumer this delivery is for
  delivery_info.consumer # => the channel this delivery is on
end
```

This allows using `Bunny::Queue#subscribe` for one-off consumers
much easier, including when used with the `:block` option.

### Bunny::Exchange#wait_for_confirms

`Bunny::Exchange#wait_for_confirms` is a convenience method on `Bunny::Exchange` that
delegates to the method with the same name on exchange's channel.


## Changes between Bunny 0.9.0.pre11 and 0.9.0.pre12

### Ruby 1.8 Compatibility Regression Fix

`Bunny::Socket` no longer uses Ruby 1.9-specific constants.


### Bunny::Channel#wait_for_confirms Return Value Regression Fix

`Bunny::Channel#wait_for_confirms` returns `true` or `false` again.



## Changes between Bunny 0.9.0.pre10 and 0.9.0.pre11

### Bunny::Session#create_channel Now Accepts Consumer Work Pool Size

`Bunny::Session#create_channel` now accepts consumer work pool size as
the second argument:

``` ruby
# nil means channel id will be allocated by Bunny.
# 8 is the number of threads in the consumer work pool this channel will use.
ch = conn.create_channel(nil, 8)
```

### Heartbeat Fix For Long Running Consumers

Long running consumers that don't send any data will no longer
suffer from connections closed by RabbitMQ because of skipped
heartbeats.

Activity tracking now takes sent frames into account.


### Time-bound continuations

If a network loop exception causes "main" session thread to never
receive a response, methods such as `Bunny::Channel#queue` will simply time out
and raise Timeout::Error now, which can be handled.

It will not start automatic recovery for two reasons:

 * It will be started in the network activity loop anyway
 * It may do more damage than good

Kicking off network recovery manually is a matter of calling
`Bunny::Session#handle_network_failure`.

The main benefit of this implementation is that it will never
block the main app/session thread forever, and it is really
efficient on JRuby thanks to a j.u.c. blocking queue.

Fixes #112.


### Logging Support

Every Bunny connection now has a logger. By default, Bunny will use STDOUT
as logging device. This is configurable using the `:log_file` option:

``` ruby
require "bunny"

conn = Bunny.new(:log_level => :warn)
```

or the `BUNNY_LOG_LEVEL` environment variable that can take one of the following
values:

 * `debug` (very verbose)
 * `info`
 * `warn`
 * `error`
 * `fatal` (least verbose)

Severity is set to `warn` by default. To disable logging completely, set the level
to `fatal`.

To redirect logging to a file or any other object that can act as an I/O entity,
pass it to the `:log_file` option.


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
