---
title: "Connecting to RabbitMQ from Ruby with Bunny"
layout: article
---

## About this guide

This guide covers connection to RabbitMQ with Bunny, connection error
handling, authentication failure handling and related issues.

This work is licensed under a <a rel="license"
href="http://creativecommons.org/licenses/by/3.0/">Creative Commons
Attribution 3.0 Unported License</a> (including images and
stylesheets). The source is available [on
GitHub](https://github.com/ruby-amqp/rubybunny.info).


## What version of Bunny does this guide cover?

This guide covers Bunny 2.11.0 and later versions.

## Two ways to specify connection parameters

With Bunny, connection parameters (host, port, username, vhost and so
on) can be passed in two forms:

 * As a map of attributes
 * As a connection URI string (à la JDBC)


### Using a Map of Parameters

Map options that Bunny will recognize are

 * `:host` (string, default: `"127.0.0.1"`)
 * `:port` (integer, default: `5672`)
 * `:user` or `:username` (string, default: `"guest"`)
 * `:pass` or `:password` (string, default: `"guest"`)
 * `:vhost` or `virtual_host` (string, default: `'/'`)
 * `:heartbeat` or `:heartbeat_timeout` (string or integer, default: `:server`): the desired [heartbeat timeout](http://www.rabbitmq.com/heartbeats.html). `:server` means "use the value from RabbitMQ config". `0` means no heartbeats (**not recommended**).
 * `:logger` (Logger): The logger. If missing, one is created using `:log_file` and `:log_level`.
 * `:log_level` (symbol or integer, default: `Logger::WARN`): Log level to use when creating a logger.
 * `:log_file` (string or `IO`, default: `STDOUT`): log file or `IO` object to use when creating a logger
 * `:automatically_recover` (boolean, default: `true`): when `false`, will disable automatic network failure recovery
 * `:network_recovery_interval` (number, default: `5.0`): interval between reconnection attempts
 * `:threaded` (boolean, default: `true`): switches to single-threaded connections when set to `false`. Only recommended for apps that only publish messages.
 * `:continuation_timeout` (integer, default: `4000` ms): timeout for client operations that expect a response (e.g. `Bunny::Queue#get`), in *milliseconds*.
 * `:frame_max` (integer, default: `131072`): maximum permissible size of a frame (in bytes) to negotiate with clients. Setting to 0 means "unlimited" but will trigger a bug in some QPid clients. Setting a larger value may improve throughput; setting a smaller value may improve latency.
 * `:auth_mechanism` (string or array, default: `"PLAIN"`): Mechanism to authenticate with the server. Currently supporting `"PLAIN"` and `"EXTERNAL"`.

plus TLS connection parameters covered in [Using TLS (SSL) Connections](/articles/tls.html).

To connect to RabbitMQ with a map of parameters, pass them to `Bunny.new`. The connection
will be established when `Bunny::Session#start` is called:

``` ruby
conn = Bunny.new(:host => "localhost", :vhost => "myapp.production", :user => "bunny", :password => "t0ps3kret")
conn.start
```

`Bunny.new` returns a connection instance that is used to open
channels. More about channels later in this guide.

#### Default parameters

Default connection parameters are

``` ruby
{
  :host      => "127.0.0.1",
  :port      => 5672,
  :ssl       => false,
  :vhost     => "/",
  :user      => "guest",
  :pass      => "guest",
  :heartbeat => :server, # will use RabbitMQ setting
  :frame_max => 131072,
  :auth_mechanism => "PLAIN"
}
```

### Single-Threaded Mode

Bunny 0.9+ uses a separate thread for network (I/O) activity. In some
cases, developers may want to disable it and handle network failure
issues manually. This is possible by passing the `:threaded` option as
`false`.


### Reconnection Interval

When Bunny detects a network issue, it will by default try to
reconnect. This behavior can be tweaked using two options:

 * `:network_recovery_interval` controls for how long Bunny will wait between reconnection attempts (including the first one). The value is in seconds, `5.0` is the default.
 * `:automatically_recover` can be set to `false` to completely disable network recovery. In such case, Bunny will raise
    exceptions on the thread `Bunny::Session` was instantiated on.


### Using Connection Strings

It is also possible to specify connection parameters as a URI string:

``` ruby
b = Bunny.new("amqp://guest:guest@vm188.dev.megacorp.com/profitd.qa")
b.start
```

Unfortunately, there is no URI standard for AMQP URIs, so while several schemes used in the wild share the same basic idea, they differ in some details.
The implementation used by Bunny aims to encourage URIs that work as widely as possible.

Here are some examples of valid AMQP URIs:

 * amqp://dev.rabbitmq.com
 * amqp://dev.rabbitmq.com:5672
 * amqp://guest:guest@dev.rabbitmq.com:5672
 * amqp://hedgehog:t0ps3kr3t@hub.megacorp.internal/production
 * amqps://hub.megacorp.internal/%2Fvault
 * amqps://rabbitmq.com/staging?heartbeat=10&channel_max=1000

The URI scheme should be "amqp", or "amqps" if SSL is required.

The host, port, username and password are represented in the authority
component of the URI in the same way as in HTTP URIs.

The vhost is obtained from the first segment of the path, with the
leading slash removed.  The path should contain only a single segment
(i.e, the only slash in it should be the leading one). If the vhost is
to include slashes or other reserved URI characters, these should be
percent-escaped.

Here are some examples that demonstrate how
`AMQ::Settings.parse_amqp_url` parses out the vhost from connection
URIs:

``` ruby
AMQ::Settings.parse_amqp_url("amqp://dev.rabbitmq.com")            # => vhost is nil, so default ("/") will be used
AMQ::Settings.parse_amqp_url("amqp://dev.rabbitmq.com/")           # => vhost is an empty string
AMQ::Settings.parse_amqp_url("amqp://dev.rabbitmq.com/%2Fvault")   # => vhost is "/vault"
AMQ::Settings.parse_amqp_url("amqp://dev.rabbitmq.com/production") # => vhost is "production"
AMQ::Settings.parse_amqp_url("amqp://dev.rabbitmq.com/a.b.c")      # => vhost is "a.b.c"
AMQ::Settings.parse_amqp_url("amqp://dev.rabbitmq.com/foo/bar")    # => ArgumentError
```

Bunny is able to parse [RabbitMQ URI query parameters](https://www.rabbitmq.com/uri-query-parameters.html), where you may specify some common client connection attributes:

 * `auth_mechanism`
 * `heartbeat`
 * `connection_timout`
 * `channel_max`
 * `verify`
 * `fail_if_no_peer_cert`
 * `cacertfile`
 * `certfile`
 * `keyfile`
 
 Here is an example:
 
```ruby
b = Bunny.new("amqps://rabbitmq?heartbeat=10&connection_timeout=100&channel_max=1000&verify=true&fail_if_no_peer_cert=true&cacertfile=/examples/tls/cacert.pem&certfile=/examples/tls/client_cert.pem&keyfile=/examples/tls/client_key.pem")
b.start
b.user #=> "guest"
b.pass #=> "guest"
b.hostname #=> "rabbitmq"
b.port #=> 5671
b.vhost #=> "/"
b.heartbeat #=> 10
b.transport.connect_timeout #=> 100
b.channel_max #=> 1000
b.ssl #=> true
b.transport.verify_peer #=> false
b.transport.tls_ca_certificates #=> "/examples/tls/cacert.pem"
b.transport.tls_ca_certificates #=> "/examples/tls/client_cert.pem"
b.transport.tls_key_path #=> "/examples/tls/client_key.pem"
```

Pay attention that some attibutes are not allowed for specific scheme, particularly TLS options don't make sense for "amqp" scheme.
  

### Connection Failures

If a connection does not succeed, Bunny will raise one of the
following exceptions:

 * `Bunny::PossibleAuthenticationFailureException` indicates an authentication issue or that connection to RabbitMQ was closed before successfully finishing connection negotiation
 * `Bunny::TCPConnectionFailed` indicates that connection to the host has failed. Either the address is not reachable or DNS entry does not exist. Often may suggest a misconfiguration.
 * `Bunny::NetworkFailure` for other exceptions in the I/O thread.

When [automatic connection recovery mode](/articles/error_handling.html) is disabled,
Bunny will raise exceptions on the thread `Bunny::Session` was instantiated.


## PaaS Environments

### The RABBITMQ_URL Environment Variable

If no arguments are passed to `Bunny.new` but the `RABBITMQ_URL`
environment variable is set, Bunny will use it as connection URI.


## Opening a Channel

Some applications need multiple connections to RabbitMQ. However, it
is undesirable to keep many TCP connections open at the same time
because doing so consumes system resources and makes it more difficult
to configure firewalls. AMQP 0-9-1 connections are multiplexed with
channels that can be thought of as "lightweight connections that share
a single TCP connection".

To open a channel, use the `Bunny::Session#create_channel` method:

``` ruby
conn = Bunny.new
conn.start

ch   = conn.create_channel
```

Channels are typically long lived: you open one or more of them and
use them for a period of time, as opposed to opening a new channel for
each published message, for example.


## Closing Channels

To close a channel, use the `Bunny::Channel#close` method. A closed
channel can no longer be used.

``` ruby
conn = Bunny.new
conn.start

ch   = conn.create_channel
ch.close
```


## Connecting in Web applications (Ruby on Rails, Sinatra, etc)

When connecting in Web apps, the rule of thumb is: do it in an
initializer, not controller actions or request handlers.

### Using Bunny with Unicorn

[Unicorn](http://unicorn.bogomips.org) is a pre-forking server. That
means it forks worker processes that serve HTTP requests. The
"[fork(2)](http://en.wikipedia.org/wiki/Fork_(operating_system)) system
call has several gotchas associated with it:

 * Unintentional file descriptor sharing
 * The fact that a [forked child process only inherits one thread](http://bit.ly/fork-and-threads) and therefore the network I/O thread is not inherited

To avoid both problems, connect to RabbitMQ *after* the master process
forks workers. The master Unicorn process never serves HTTP requests
and usually does not need to hold a RabbitMQ connection. Next, let us
see how to connect to the broker after Unicorn forks a worker.

Unicorn lets you specify a configuration file to use. In that file you
define a callback that Unicorn runs after it forks worker process(es):

``` ruby
preload_app true

after_fork do |server, worker|
  require "bunny"

  # the following is *required* for Rails + "preload_app true",
  defined?(ActiveRecord::Base) and
    ActiveRecord::Base.establish_connection

    $rabbitmq_connection = Bunny.new
    $rabbitmq_connection.start

    $rabbitmq_channel    = $rabbitmq_connection.create_channel
 end
end
```

In the example above we connect to RabbitMQ after Unicorn has forked off
child processes.

Note that a configuration file can easily be used in development
environments because, other than the fact that Unicorn runs in the
foreground, it gives you exactly the same application boot behavior as
in QA and production environments.


### Using Bunny with Passenger

[Phusion Passenger](http://www.modrails.com) is also a pre-forking
server, and just as with Unicorn, clients should connect to RabbitMQ
**after** it forks worker processes. The Passenger documentation has
[a section](https://www.phusionpassenger.com/library/indepth/ruby/spawn_methods/#unintentional-file-descriptor-sharing) that explains how
to avoid problems related to the behavior of the fork(2) system call,
namely:

 * Unintentional file descriptor sharing
 * The fact that a [forked child process only inherits one thread](http://bit.ly/fork-and-threads) and therefore network I/O loop thread is not inherited.

#### Using Event Handler to Spawn One Connection Per Worker Process

Passenger provides a hook that you should use for spawning RabbitMQ
connections:

``` ruby
if defined?(PhusionPassenger) # otherwise it breaks rake commands if you put this in an initializer
  PhusionPassenger.on_event(:starting_worker_process) do |forked|
    if forked
       # We’re in a smart spawning mode
       # Now is a good time to connect to RabbitMQ
       $rabbitmq_connection = Bunny.new
       $rabbitmq_connection.start

       $rabbitmq_channel    = $rabbitmq_connection.create_channel
    end
  end

  PhusionPassenger.on_event(:stopping_worker_process) do
    if $rabbitmq_connection
      $rabbitmq_connection.close
    end
  end
end
```

Basically, the recommended default smart spawn mode works exactly the
same as in Unicorn.

### Ruby on Rails

Currently Bunny does not have integration points for Rails (e.g. a
rail tie).


## Disconnecting

To close a connection, use the `Bunny::Session#close` function. This
will automatically close all channels of that connection first:

``` ruby
conn = Bunny.new
conn.start

conn.close
```


## Troubleshooting

If you have read this guide and still have issues with connecting,
check our [Troubleshooting guide](/articles/troubleshooting.html) and
feel free to ask [on the mailing
list](https://groups.google.com/forum/#!forum/ruby-amqp).


## Wrapping Up

There are two ways to specify connection parameters with Bunny: with a
map of parameters or via URI string.  Connection issues are indicated
by various exceptions. If the `RABBITMQ_URL` env variable is set,
Bunny will use its value as RabbitMQ connection URI.


## What to Read Next

The documentation is organized as [a number of
guides](/articles/guides.html), covering various topics.

We recommend that you read the following guides first, if possible, in
this order:

 * [Queues and Consumers](/articles/queues.html)
 * [Exchanges and Publishing](/articles/exchanges.html)
 * [Bindings](/articles/bindings.html)
 * [RabbitMQ Extensions to AMQP 0.9.1](/articles/extensions.html)
 * [Durability and Related Matters](/articles/durability.html)
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
