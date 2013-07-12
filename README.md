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

 * CRuby 1.9.3, 1.9.2, 2.0.0, and 1.8.7
 * JRuby 1.7+
 * Rubinius 2.0+


## Supported RabbitMQ Versions

Bunny `0.8.x` and later versions only support RabbitMQ 2.x and 3.x.
Bunny `0.7.x` and earlier versions support RabbitMQ 1.x and 2.x.


## Project Maturity

Bunny is a pretty old (started circa late 2008) library that, before version 0.9, **a lot** of missing functionality. Version 0.9
can be considered to be "second birthday" for Bunny as it was rewritten from scratch. Key objectives
for 0.9 are

 * Be feature complete, support all RabbitMQ 3.x features
 * Eliminate limitations Bunny used to have with earlier versions
 * Be [well documented](http://rubybunny.info)
 * Make use of concurrency and, if the runtime provides it, parallelism
 * Reuse code with amqp gem and possibly other clients where it makes sense

We (the maintainers) make our best to keep the new version as
backwards compatible as possible but within reason.


## Installation & Bundler Dependency

To install Bunny 0.9.x with RubyGems:

```
gem install bunny
```

the most recent 0.9.x version is `0.9.0`.

To use Bunny 0.9.x in a project managed with Bundler:

``` ruby
gem "bunny", ">= 0.9.0" # optionally: , :git => "git://github.com/ruby-amqp/bunny.git", :branch => "master"
```


## Quick Start for Bunny 0.9.x

Below is a small snippet that demonstrates how to publish
and synchronously consume ("pull API") messages with Bunny 0.9.

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

[Bunny a mailing list](http://groups.google.com/group/ruby-amqp). We encourage you
to also join the [rabbitmq-discuss](https://lists.rabbitmq.com/cgi-bin/mailman/listinfo/rabbitmq-discuss) mailing list. Feel free to ask any questions that you may have.


### IRC

For more immediate help, please join `#rabbitmq` on `irc.freenode.net`.


### News & Announcements on Twitter

To subscribe for announcements of releases, important changes and so on, please follow [@rubyamqp](https://twitter.com/#!/rubyamqp) on Twitter.

More detailed announcements can be found in the blogs

* [RabbitMQ Ruby clients blog](http://blog.rubyrabbitmq.info)
* [Bunny Blog](http://bunnyamqp.wordpress.com)


### Reporting Issues

If you find a bug, poor default, missing feature or find any part of the API inconvenient, please [file an issue](http://github.com/ruby-amqp/bunny/issues) on GitHub.
When filing an issue, please specify which Bunny and RabbitMQ versions you are using, provide recent RabbitMQ log file contents if possible,
and try to explain what behavior you expected and why. Bonus points for contributing failing test cases.


## Other Ruby RabbitMQ Clients

Other widely used Ruby RabbitMQ clients are [Hot Bunnies](http://github.com/ruby-amqp/hot_bunnies) (JRuby-only) and [amqp gem](http://rubyamqp.info).
Both are mature libraries and require RabbitMQ 2.x or 3.x.


## Contributing

First, clone the repository and run

    bundle install --binstubs

then set up RabbitMQ vhosts with

    ./bin/ci/before_build.sh

(if needed, set `RABBITMQCTL` env variable to point to `rabbitmqctl` you want to use)

and then run tests with

    ./bin/rspec -cfs spec

After that create a branch and make your changes on it. Once you are done with your changes and all tests pass, submit a pull request
on GitHub.


## License

Released under the MIT license.
