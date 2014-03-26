# Bunny, a Ruby RabbitMQ Client

Bunny is a synchronous RabbitMQ client that focuses on ease of use. It
is feature complete, supports all RabbitMQ 3.0 features and does not
have any heavyweight dependencies.


## I Know What RabbitMQ and Bunny are, How Do I Get Started?

[Right here](http://rubybunny.info/articles/getting_started.html)!


## What is Bunny Good For?

One can use amqp gem to make Ruby applications interoperate with other
applications (both Ruby and not). Complexity and size may vary from
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

Bunny 0.9 and more recent versions support

 * CRuby 2.1, CRuby 2.0, 1.9.3, 1.9.2, and 1.8.7
 * Rubinius 2.0+

Bunny works sufficiently well on JRuby but there are known
JRuby bugs that cause high CPU burn. JRuby users should
use [March Hare](http://rubymarchhare.info).


## Supported RabbitMQ Versions

Bunny `0.8.x` and later versions only support RabbitMQ 2.x and 3.x.
Bunny `0.7.x` and earlier versions support RabbitMQ 1.x and 2.x.


## Project Maturity

Bunny is a mature library (started in early 2009) library with
a stable public API.

Before version 0.9, **a lot** of functionality was missing.  Version
0.9 can be considered to be "second birthday" for Bunny as it was
rewritten from scratch with over a dozen of preview releases over the
course of about a year.

We (the maintainers) made our best effort to keep the new version as
backwards compatible as possible but within reason.


## Installation & Bundler Dependency

### Most Recent Release

[![Gem Version](https://badge.fury.io/rb/bunny.png)](http://badge.fury.io/rb/bunny)

### With Rubygems

To install Bunny with RubyGems:

```
gem install bunny
```

### Bundler Dependency

To use Bunny in a project managed with Bundler:

``` ruby
gem "bunny", "~> 1.1.7"
```


## Quick Start

Below is a small snippet that demonstrates how to publish
and synchronously consume ("pull API") messages with Bunny.

For a 15 minute tutorial using more practical examples, see [Getting Started with RabbitMQ and Ruby using Bunny](http://rubybunny.info/articles/getting_started.html).

``` ruby
require "bunny"

# Start a communication session with RabbitMQ
conn = Bunny.new
conn.start

# open a channel
ch = conn.create_channel

# declare a queue
q  = ch.queue("test1")

# publish a message to the default exchange which then gets routed to this queue
q.publish("Hello, everybody!")

# fetch a message from the queue
delivery_info, metadata, payload = q.pop

puts "This is the message: #{payload}"

# close the connection
conn.stop
```


## Documentation

### Getting Started

For a 15 minute tutorial using more practical examples, see [Getting Started with RabbitMQ and Ruby using Bunny](http://rubybunny.info/articles/getting_started.html).

### Guides

Other documentation guides are available at [rubybunny.info](http://rubybunny.info):

 * [Queues and Consumers](http://rubybunny.info/articles/queues.html)
 * [Exchanges and Publishers](http://rubybunny.info/articles/exchanges.html)
 * [AMQP 0.9.1 Model Explained](http://www.rabbitmq.com/tutorials/amqp-concepts.html)
 * [Connecting to RabbitMQ](http://rubybunny.info/articles/connecting.html)
 * [Error Handling and Recovery](http://rubybunny.info/articles/error_handling.html)
 * [TLS/SSL Support](http://rubybunny.info/articles/tls.html)
 * [Bindings](http://rubybunny.info/articles/bindings.html)
 * [Using RabbitMQ Extensions with Bunny](http://rubybunny.info/articles/extensions.html)
 * [Durability and Related Matters](http://rubybunny.info/articles/durability.html)

### API Reference

[Bunny API Reference](http://reference.rubybunny.info/).


## Community and Getting Help

### Mailing List

[Bunny has a mailing list](http://groups.google.com/group/ruby-amqp). We encourage you
to also join the [rabbitmq-discuss](https://lists.rabbitmq.com/cgi-bin/mailman/listinfo/rabbitmq-discuss) mailing list. Feel free to ask any questions that you may have.


### IRC

For more immediate help, please join `#rabbitmq` on `irc.freenode.net`.


### News & Announcements on Twitter

To subscribe for announcements of releases, important changes and so on, please follow [@rubyamqp](https://twitter.com/#!/rubyamqp) on Twitter.

More detailed announcements can be found in the blogs

* [RabbitMQ Ruby clients blog](http://blog.rubyrabbitmq.info)
* [Bunny Blog](http://bunnyamqp.wordpress.com)


### Reporting Issues

If you find a bug, poor default, missing feature or find any part of
the API inconvenient, please [file an
issue](http://github.com/ruby-amqp/bunny/issues) on GitHub.  When
filing an issue, please specify which Bunny and RabbitMQ versions you
are using, provide recent RabbitMQ log file contents if possible, and
try to explain what behavior you expected and why. Bonus points for
contributing failing test cases.


## Other Ruby RabbitMQ Clients

Other widely used Ruby RabbitMQ clients are [March
Hare](http://rubymarchhare.info) (JRuby-only) and [amqp
gem](http://rubyamqp.info).  Both are mature libraries and require
RabbitMQ 2.x or 3.x.


## Contributing

First, clone the repository and run

    bundle install --binstubs

then set up RabbitMQ vhosts with

    ./bin/ci/before_build.sh

(if needed, set `RABBITMQCTL` env variable to point to `rabbitmqctl` you want to use)

and then run tests with

    CI=true ./bin/rspec -cfs spec

After that create a branch and make your changes on it. Once you are done with your changes and all tests pass, submit a pull request
on GitHub.


## License

Released under the MIT license.


[![Bitdeli Badge](https://d2weczhvl823v0.cloudfront.net/ruby-amqp/bunny/trend.png)](https://bitdeli.com/free "Bitdeli Badge")

