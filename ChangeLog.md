# Changes between Bunny 0.8.x and 0.9.0

## Bunny::Client.create_channel now uses a bitset-based allocator

Instead of reusing channel instances, `Bunny::Client.create_channel` now opens new channels and
uses bitset-based allocator to keep track of used channel ids. This avoids situations when
channels are reused or shared without developer's explicit intent but also work well for
long running applications that aggressively open and release channels.

This is also how amqp gem and RabbitMQ Java client manage channel ids.


## Unified Bunny::ConnectionError and Bunny::ServerDownError

In Bunny 0.8.0 and earlier, `Bunny::ServerDownError` and `Bunny::ConnectionError` large served the same purpose.
They are now just aliases.


## Bunny::ServerDownError is now Bunny::TCPConnectionFailed

`Bunny::ServerDownError` is now an alias for `Bunny::TCPConnectionFailed`
