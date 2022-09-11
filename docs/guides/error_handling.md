---
title: "Error Handling and Recovery"
layout: article
---

## About this guide

Development of a robust application, be it message publisher or
message consumer, involves dealing with multiple kinds of failures:
protocol exceptions, network failures, broker failures and so
on. Correct error handling and recovery is not easy. This guide
explains how the library helps you in dealing with issues like

 * Client exceptions
 * Initial connection failures
 * Network connection failures
 * AMQP 0.9.1 connection-level exceptions
 * AMQP 0.9.1 channel-level exceptions
 * Broker failure
 * TLS (SSL) related issues

as well as

 * How does the automatic recovery mode in Bunny 0.9+ work

This work is licensed under a <a rel="license"
href="http://creativecommons.org/licenses/by/3.0/">Creative Commons
Attribution 3.0 Unported License</a> (including images and
stylesheets). The source is available [on
GitHub](https://github.com/ruby-amqp/rubybunny.info).


## What version of Bunny does this guide cover?

This guide covers Bunny 2.11.0 and later versions.


## Client Exceptions

Here is the break-down of exceptions that can be raised by Bunny:

    StandardError
      Bunny::Exception
        Bunny::ChannelAlreadyClosed

        Bunny::ChannelLevelException
          Bunny::AccessRefused
          Bunny::ForcedChannelCloseError
          Bunny::NotFound
          Bunny::PreconditionFailed
          Bunny::ResourceLocked

        Bunny::ConnectionClosedError

        Bunny::ConnectionLevelException
          Bunny::ChannelError
          Bunny::CommandInvalid
          Bunny::ConnectionForced
          Bunny::ForcedConnectionCloseError
          Bunny::FrameError
          Bunny::InternalError
          Bunny::ResourceError
          Bunny::UnexpectedFrame

        Bunny::InconsistentDataError
          Bunny::BadLengthError
          Bunny::NoFinalOctetError

        Bunny::NetworkFailure
        Bunny::NotAllowedError

        Bunny::PossibleAuthenticationFailureError
          Bunny::AuthenticationFailureError

        Bunny::ShutdownSignal
        Bunny::TCPConnectionFailed

    Timeout::Error
      Bunny::ClientTimeout
      Bunny::ConnectionTimeout

The rest of the document describes the most common ones.
See [Bunny exception definitions](https://raw.githubusercontent.com/ruby-amqp/bunny/master/lib/bunny/exceptions.rb) for more details.


## Initial RabbitMQ Connection Failures

When applications connect to the broker, they need to handle
connection failures. Networks are not 100% reliable, even with modern
system configuration tools like Chef or Puppet misconfigurations
happen and the broker might also be down. Error detection should
happen as early as possible. To handle TCP
connection failure, catch the `Bunny::TCPConnectionFailure` exception:

``` ruby
begin
  conn = Bunny.new("amqp://guest:guest@aksjhdkajshdkj.example82737.com")
  conn.start
rescue Bunny::TCPConnectionFailed => e
  puts "Connection to aksjhdkajshdkj.example82737.com failed"
end
```

`Bunny::Session#start` will raise `Bunny::TCPConnectionFailed` if a
connection fails. Code that catches it can write to a log about the
issue or use retry to execute the begin block one more time. Because
initial connection failures are due to misconfiguration or network
outage, reconnection to the same endpoint (hostname, port, vhost
combination) may result in the same issue over and over.


## Authentication Failures

Another reason why a connection may fail is authentication
failure. Handling authentication failure is very similar to handling
initial TCP connection failure:

``` ruby
begin
  conn = Bunny.new("amqp://guest8we78w7e8:guest2378278@127.0.0.1")
  conn.start
rescue Bunny::PossibleAuthenticationFailureError => e
  puts "Could not authenticate as #{conn.username}"
end
```

In case you are wondering why the exception name has "possible" in it:
[AMQP 0.9.1 spec](http://www.rabbitmq.com/resources/specs/amqp0-9-1.pdf) requires broker
implementations to simply close TCP connection without sending any
more data when an exception (such as authentication failure) occurs
before AMQP connection is open. In practice, however, when broker
closes TCP connection between successful TCP connection and before
AMQP connection is open, it means that authentication has failed.

RabbitMQ 3.2 introduces [authentication failure notifications](http://www.rabbitmq.com/auth-notification.html)
which Bunny supports. When connecting to RabbitMQ 3.2 or later, Bunny will
raise `Bunny::AuthenticationFailureError` when it receives a proper
authentication failure notification.


## Network Connection Failures

Detecting network connections is nearly useless if an application
cannot recover from them. Recovery is the hard part in "error handling
and recovery". Fortunately, the recovery process for many applications
follows a common scheme that Bunny can perform automatically for
you.

When Bunny detects TCP connection failure, it will try to reconnect
every 5 seconds. Currently there is no limit on the number of reconnection
attempts.

To disable automatic connection recovery, pass `:automatic_recovery => false`
to `Bunny.new`.

### Server-Initiated `connection.close`

Server-initiated `connection.close` (issued due to an unrecoverable client
issue or when a connection is forced to close via RabbitMQ management UI/HTTP API
or when a server is shutting down)will result in an exception on the thread
`Bunny::Session` was instantiated.

Bunny can be instructed from such exceptions (see Automatic Recovery below).


### Automatic Recovery

Many applications use the same recovery strategy that consists of the following steps:

 * Re-open channels
 * For each channel, re-declare exchanges (except for predefined ones)
 * For each channel, re-declare queues
 * For each queue, recover all bindings
 * For each queue, recover all consumers

Bunny provides a feature known as "automatic recovery" that performs these steps
after connection recovery, while taking care of some of the more tricky details
such as recovery of server-named queues with consumers.

Currently the topology recovery strategy is not configurable.

When automatic recovery is disabled, Bunny will raise
exceptions on the thread `Bunny::Session` was instantiated on.

Bunny will recover from server-sent `connection.close`, if you don't want it to do
so then pass `recover_from_connection_close: false` to `Bunny.new`. 


## Channel-level Exceptions

Channel-level exceptions are more common than connection-level ones and often indicate
issues applications can recover from (such as consuming from or trying to delete
a queue that does not exist).

With Bunny, channel-level exceptions are raised as Ruby exceptions, for example,
`Bunny::NotFound`, that provide access to the underlying `channel.close` method
information:

``` ruby
begin
  ch.queue_delete("queue_that_should_not_exist#{rand}")
rescue Bunny::NotFound => e
  puts "Channel-level exception! Code: #{e.channel_close.reply_code}, message: #{e.channel_close.reply_text}"
end
```

``` ruby
begin
  ch2 = conn.create_channel
  q   = "bunny.examples.recovery.q#{rand}"

  ch2.queue_declare(q, :durable => false)
  ch2.queue_declare(q, :durable => true)
rescue Bunny::PreconditionFailed => e
  puts "Channel-level exception! Code: #{e.channel_close.reply_code}, message: #{e.channel_close.reply_text}"
ensure
  conn.create_channel.queue_delete(q)
end
```


### Common channel-level exceptions and what they mean

A few channel-level exceptions are common and deserve more attention.

#### 406 Precondition Failed

<dl>
  <dt>Description</dt>
  <dd>The client requested a method that was not allowed because some precondition failed.</dd>
  <dt>What might cause it</dt>
  <dd>
    <ul>
      <li>AMQP entity (a queue or exchange) was re-declared with attributes different from original declaration. Maybe two applications or pieces of code declare the same entity with different attributes. Note that different RabbitMQ client libraries historically use slightly different defaults for entities and this may cause attribute mismatches.</li>
      <li>`Bunny::Channel#tx_commit` or `Bunny::Channel#tx_rollback` might be run on a channel that wasn't previously made transactional with `Bunny::Channel#tx_select`</li>
    </ul>
  </dd>
  <dt>Example RabbitMQ error message</dt>
  <dd>
    <ul>
      <li>PRECONDITION_FAILED - parameters for queue 'bunny.examples.channel_exception' in vhost '/' not equivalent</li>
      <li>PRECONDITION_FAILED - channel is not transactional</li>
    </ul>
  </dd>
</dl>

#### 405 Resource Locked

<dl>
  <dt>Description</dt>
  <dd>The client attempted to work with a server entity to which it has no access because another client is working with it.</dd>
  <dt>What might cause it</dt>
  <dd>
    <ul>
      <li>Multiple applications (or different pieces of code/threads/processes/routines within a single application) might try to declare queues with the same name as exclusive.</li>
      <li>Multiple consumer across multiple or single app might be registered as exclusive for the same queue.</li>
    </ul>
  </dd>
  <dt>Example RabbitMQ error message</dt>
  <dd>RESOURCE_LOCKED - cannot obtain exclusive access to locked queue 'bunny.examples.queue' in vhost '/'</dd>
</dl>

#### 404 Not Found

<dl>
  <dt>Description</dt>
  <dd>The client attempted to use (publish to, delete, etc) an entity (exchange, queue) that does not exist.</dd>
  <dt>What might cause it</dt>
  <dd>Application miscalculates queue or exchange name or tries to use an entity that was deleted earlier</dd>
  <dt>Example RabbitMQ error message</dt>
  <dd>NOT_FOUND - no queue 'queue_that_should_not_exist0.6798199937619038' in vhost '/'</dd>
</dl>

#### 403 Access Refused

<dl>
  <dt>Description</dt>
  <dd>The client attempted to work with a server entity to which it has no access due to security settings.</dd>
  <dt>What might cause it</dt>
  <dd>Application tries to access a queue or exchange it has no permissions for (or right kind of permissions, for example, write permissions)</dd>
  <dt>Example RabbitMQ error message</dt>
  <dd>ACCESS_REFUSED - access to queue 'bunny.examples.channel_exception' in vhost 'bunny_testbed' refused for user 'bunny_reader'</dd>
</dl>




## What to Read Next

The documentation is organized as [a number of
guides](/articles/guides.html), covering various topics.

We recommend that you read the following guides first, if possible, in this order:

 * [Troubleshooting](/articles/troubleshooting.html)
 * [Using TLS (SSL) Connections](/articles/tls.html)


## Tell Us What You Think!

Please take a moment to tell us what you think about this guide [on Twitter](http://twitter.com/rubyamqp) or the [Bunny mailing list](https://groups.google.com/forum/#!forum/ruby-amqp)

Let us know what was unclear or what has not been covered. Maybe you
do not like the guide style or grammar or discover spelling
mistakes. Reader feedback is key to making the documentation better.
