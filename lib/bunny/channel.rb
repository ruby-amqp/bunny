# -*- coding: utf-8 -*-
require "thread"
require "set"

require "bunny/consumer_work_pool"

require "bunny/exchange"
require "bunny/queue"

require "bunny/delivery_info"
require "bunny/return_info"
require "bunny/message_properties"

module Bunny
  # ## What are AMQP channels
  #
  # To quote {http://www.rabbitmq.com/resources/specs/amqp0-9-1.pdf AMQP 0.9.1 specification}:
  #
  # AMQP 0.9.1 is a multi-channelled protocol. Channels provide a way to multiplex
  # a heavyweight TCP/IP connection into several light weight connections.
  # This makes the protocol more “firewall friendly” since port usage is predictable.
  # It also means that traffic shaping and other network QoS features can be easily employed.
  # Channels are independent of each other and can perform different functions simultaneously
  # with other channels, the available bandwidth being shared between the concurrent activities.
  #
  #
  # ## Opening Channels
  #
  # Channels can be opened either via `Bunny::Session#create_channel` (sufficient in the majority
  # of cases) or by instantiating `Bunny::Channel` directly:
  #
  # @example Using {Bunny::Session#create_channel}:
  #   conn = Bunny.new
  #   conn.start
  #
  #   ch   = conn.create_channel
  #
  # This will automatically allocate channel id.
  #
  # @example Instantiating
  #
  # ## Closing Channels
  #
  # Channels are closed via {Bunny::Channel#close}. Channels that get a channel-level exception are
  # closed, too. Closed channels can no longer be used. Attempts to use them will raise
  # {Bunny::ChannelAlreadyClosed}.
  #
  # @example
  #
  #   ch  = conn.create_channel
  #   ch.close
  #
  # ## Higher-level API
  #
  # Bunny offers two sets of methods on {Bunny::Channel}: known as higher-level and lower-level
  # APIs, respectively. Higher-level API mimics {http://rubyamqp.info amqp gem} API where
  # exchanges and queues are objects (instance of {Bunny::Exchange} and {Bunny::Queue}, respectively).
  # Lower-level API is built around AMQP 0.9.1 methods (commands), where queues and exchanges are
  # passed as strings (à la RabbitMQ Java client, {http://clojurerabbitmq.info Langohr} and Pika).
  #
  # ### Queue Operations In Higher-level API
  #
  # * {Bunny::Channel#queue} is used to declare queues. The rest of the API is in {Bunny::Queue}.
  #
  #
  # ### Exchange Operations In Higher-level API
  #
  # * {Bunny::Channel#topic} declares a topic exchange. The rest of the API is in {Bunny::Exchange}.
  # * {Bunny::Channel#direct} declares a direct exchange.
  # * {Bunny::Channel#fanout} declares a fanout exchange.
  # * {Bunny::Channel#headers} declares a headers exchange.
  # * {Bunny::Channel#default_exchange}
  # * {Bunny::Channel#exchange} is used to declare exchanges with type specified as a symbol or string.
  #
  #
  # ## Channel Qos (Prefetch Level)
  #
  # It is possible to control how many messages at most a consumer will be given (before it acknowledges
  # or rejects previously consumed ones). This setting is per channel and controlled via {Bunny::Channel#prefetch}.
  #
  #
  # ## Channel IDs
  #
  # Channels are identified by their ids which are integers. Bunny takes care of allocating and
  # releasing them as channels are opened and closed. It is almost never necessary to specify
  # channel ids explicitly.
  #
  # There is a limit on the maximum number of channels per connection, usually 65536. Note
  # that allocating channels is very cheap on both client and server so having tens, hundreds
  # or even thousands of channels is not a problem.
  #
  # ## Channels and Error Handling
  #
  # Channel-level exceptions are more common than connection-level ones and often indicate
  # issues applications can recover from (such as consuming from or trying to delete
  # a queue that does not exist).
  #
  # With Bunny, channel-level exceptions are raised as Ruby exceptions, for example,
  # {Bunny::NotFound}, that provide access to the underlying `channel.close` method
  # information.
  #
  # @example Handling 404 NOT_FOUND
  #   begin
  #     ch.queue_delete("queue_that_should_not_exist#{rand}")
  #   rescue Bunny::NotFound => e
  #     puts "Channel-level exception! Code: #{e.channel_close.reply_code}, message: #{e.channel_close.reply_text}"
  #   end
  #
  # @example Handling 406 PRECONDITION_FAILED
  #   begin
  #     ch2 = conn.create_channel
  #     q   = "bunny.examples.recovery.q#{rand}"
  #
  #     ch2.queue_declare(q, :durable => false)
  #     ch2.queue_declare(q, :durable => true)
  #   rescue Bunny::PreconditionFailed => e
  #     puts "Channel-level exception! Code: #{e.channel_close.reply_code}, message: #{e.channel_close.reply_text}"
  #   ensure
  #     conn.create_channel.queue_delete(q)
  #   end
  #
  # @see http://www.rabbitmq.com/tutorials/amqp-concepts.html AMQP 0.9.1 Model Concepts Guide
  # @see http://rubybunny.info/articles/getting_started.html Getting Started with RabbitMQ Using Bunny
  # @see http://rubybunny.info/articles/error_handling.html Error Handling and Recovery Guide
  class Channel

    #
    # API
    #
    # @return [Integer] Channel id
    attr_accessor :id
    # @return [Bunny::Session] AMQP connection this channel was opened on
    attr_reader :connection
    attr_reader :status
    # @return [Bunny::ConsumerWorkPool] Thread pool delivered messages are dispatched to.
    attr_reader :work_pool
    # @return [Integer] Next publisher confirmations sequence index
    attr_reader :next_publish_seq_no
    # @return [Hash<String, Bunny::Queue>] Queue instances declared on this channel
    attr_reader :queues
    # @return [Hash<String, Bunny::Exchange>] Exchange instances declared on this channel
    attr_reader :exchanges
    # @return [Set<Integer>] Set of published message indexes that are currently unconfirmed
    attr_reader :unconfirmed_set
    # @return [Set<Integer>] Set of nacked message indexes that have been nacked
    attr_reader :nacked_set
    # @return [Hash<String, Bunny::Consumer>] Consumer instances declared on this channel
    attr_reader :consumers


    # @param [Bunny::Session] connection AMQP 0.9.1 connection
    # @param [Integer] id Channel id, pass nil to make Bunny automatically allocate it
    # @param [Bunny::ConsumerWorkPool] work_pool Thread pool for delivery processing, by default of size 1
    def initialize(connection = nil, id = nil, work_pool = ConsumerWorkPool.new(1))
      @connection = connection
      @id         = id || @connection.next_channel_id
      @status     = :opening

      @connection.register_channel(self)

      @queues     = Hash.new
      @exchanges  = Hash.new
      @consumers  = Hash.new
      @work_pool  = work_pool

      # synchronizes frameset delivery. MK.
      @publishing_mutex = Mutex.new
      @consumer_mutex   = Mutex.new

      @unconfirmed_set_mutex = Mutex.new

      @continuations          = ::Queue.new
      @confirms_continuations = ::Queue.new

      @next_publish_seq_no = 0
    end

    # Opens the channel and resets its internal state
    # @return [Bunny::Channel] Self
    def open
      @connection.open_channel(self)
      # clear last channel error
      @last_channel_error = nil

      @status = :open

      self
    end

    # Closes the channel. Closed channels can no longer be used (this includes associated
    # {Bunny::Queue}, {Bunny::Exchange} and {Bunny::Consumer} instances.
    def close
      @connection.close_channel(self)
      closed!
    end

    # @return [Boolean] true if this channel is open, false otherwise
    def open?
      @status == :open
    end

    # @return [Boolean] true if this channel is closed (manually or because of an exception), false otherwise
    def closed?
      @status == :closed
    end


    #
    # @group Backwards compatibility with 0.8.0
    #

    # @return [Integer] Channel id
    def number
      self.id
    end

    # @return [Boolean] true if this channel is open
    def active
      open?
    end

    # @return [Bunny::Session] Connection this channel was opened on
    def client
      @connection
    end

    # @private
    def frame_size
      @connection.frame_max
    end

    # @endgroup


    #
    # Higher-level API, similar to amqp gem
    #

    # @group Higher-level API for exchange operations

    # Declares a fanout exchange or looks it up in the cache of previously
    # declared exchanges.
    #
    # @param [String] name Exchange name
    # @param [Hash] opts Exchange parameters
    #
    # @option opts [Boolean] :durable (false) Should the exchange be durable?
    # @option opts [Boolean] :auto_delete (false) Should the exchange be automatically deleted when no longer in use?
    # @option opts [Hash] :arguments ({}) Optional exchange arguments (used by RabbitMQ extensions)
    #
    # @return [Bunny::Exchange] Exchange instance
    # @see http://rubybunny.info/articles/exchanges.html Exchanges and Publishing guide
    # @see http://rubybunny.info/articles/extensions.html RabbitMQ Extensions to AMQP 0.9.1 guide
    def fanout(name, opts = {})
      Exchange.new(self, :fanout, name, opts)
    end

    # Declares a direct exchange or looks it up in the cache of previously
    # declared exchanges.
    #
    # @param [String] name Exchange name
    # @param [Hash] opts Exchange parameters
    #
    # @option opts [Boolean] :durable (false) Should the exchange be durable?
    # @option opts [Boolean] :auto_delete (false) Should the exchange be automatically deleted when no longer in use?
    # @option opts [Hash] :arguments ({}) Optional exchange arguments (used by RabbitMQ extensions)
    #
    # @return [Bunny::Exchange] Exchange instance
    # @see http://rubybunny.info/articles/exchanges.html Exchanges and Publishing guide
    # @see http://rubybunny.info/articles/extensions.html RabbitMQ Extensions to AMQP 0.9.1 guide
    def direct(name, opts = {})
      Exchange.new(self, :direct, name, opts)
    end

    # Declares a topic exchange or looks it up in the cache of previously
    # declared exchanges.
    #
    # @param [String] name Exchange name
    # @param [Hash] opts Exchange parameters
    #
    # @option opts [Boolean] :durable (false) Should the exchange be durable?
    # @option opts [Boolean] :auto_delete (false) Should the exchange be automatically deleted when no longer in use?
    # @option opts [Hash] :arguments ({}) Optional exchange arguments (used by RabbitMQ extensions)
    #
    # @return [Bunny::Exchange] Exchange instance
    # @see http://rubybunny.info/articles/exchanges.html Exchanges and Publishing guide
    # @see http://rubybunny.info/articles/extensions.html RabbitMQ Extensions to AMQP 0.9.1 guide
    def topic(name, opts = {})
      Exchange.new(self, :topic, name, opts)
    end

    # Declares a headers exchange or looks it up in the cache of previously
    # declared exchanges.
    #
    # @param [String] name Exchange name
    # @param [Hash] opts Exchange parameters
    #
    # @option opts [Boolean] :durable (false) Should the exchange be durable?
    # @option opts [Boolean] :auto_delete (false) Should the exchange be automatically deleted when no longer in use?
    # @option opts [Hash] :arguments ({}) Optional exchange arguments
    #
    # @return [Bunny::Exchange] Exchange instance
    # @see http://rubybunny.info/articles/exchanges.html Exchanges and Publishing guide
    # @see http://rubybunny.info/articles/extensions.html RabbitMQ Extensions to AMQP 0.9.1 guide
    def headers(name, opts = {})
      Exchange.new(self, :headers, name, opts)
    end

    # Provides access to the default exchange
    # @see http://rubybunny.info/articles/extensions.html RabbitMQ Extensions to AMQP 0.9.1 guide
    def default_exchange
      self.direct(AMQ::Protocol::EMPTY_STRING, :no_declare => true)
    end

    # Declares a headers exchange or looks it up in the cache of previously
    # declared exchanges.
    #
    # @param [String] name Exchange name
    # @param [Hash] opts Exchange parameters
    #
    # @option opts [Boolean] :durable (false) Should the exchange be durable?
    # @option opts [Boolean] :auto_delete (false) Should the exchange be automatically deleted when no longer in use?
    # @option opts [Hash] :arguments ({}) Optional exchange arguments
    #
    # @return [Bunny::Exchange] Exchange instance
    # @see http://rubybunny.info/articles/exchanges.html Exchanges and Publishing guide
    # @see http://rubybunny.info/articles/extensions.html RabbitMQ Extensions to AMQP 0.9.1 guide
    def exchange(name, opts = {})
      Exchange.new(self, opts.fetch(:type, :direct), name, opts)
    end

    # @endgroup


    # @group Higher-level API for queue operations

    # Declares an exchange or looks it up in the per-channel cache.
    #
    # @param  [String] name  Queue name. Pass an empty string to declare a server-named queue (make RabbitMQ generate a unique name).
    # @param  [Hash]   opts  Queue properties and other options
    #
    # @option options [Symbol, String] :type (:direct) Exchange type: :direct, :fanout, :topic, :headers, or a string for custom types
    # @option options [Boolean] :durable (false) Should this queue be durable?
    # @option options [Boolean] :auto-delete (false) Should this queue be automatically deleted when the last consumer disconnects?
    # @option options [Boolean] :exclusive (false) Should this queue be exclusive (only can be used by this connection, removed when the connection is closed)?
    #
    # @return [Bunny::Queue] Queue that was declared or looked up in the cache
    # @see http://rubybunny.info/articles/queues.html Queues and Consumers guide
    def queue(name = AMQ::Protocol::EMPTY_STRING, opts = {})
      q = find_queue(name) || Bunny::Queue.new(self, name, opts)

      register_queue(q)
    end

    # @endgroup


    # @group QoS and Flow Control

    # Sets how many messages will be given to consumers on this channel before they
    # have to acknowledge or reject one of the previously consumed messages
    #
    # @param [Integer] prefetch_count Prefetch (QoS setting) for this channel
    # @see http://rubybunny.info/articles/exchanges.html Exchanges and Publishing guide
    # @see http://rubybunny.info/articles/queues.html Queues and Consumers guide
    def prefetch(prefetch_count)
      self.basic_qos(prefetch_count, false)
    end

    # Flow control. When set to false, RabbitMQ will stop delivering messages on this
    # channel.
    #
    # @param [Boolean] active Should messages to consumers on this channel be delivered?
    def flow(active)
      channel_flow(active)
    end

    # Tells RabbitMQ to redeliver unacknowledged messages
    def recover(ignored = true)
      # RabbitMQ only supports basic.recover with requeue = true
      basic_recover(true)
    end

    # @endgroup



    # @group Message acknowledgements

    # Rejects a message. A rejected message can be requeued or
    # dropped by RabbitMQ.
    #
    # @param [Integer] delivery_tag Delivery tag to reject
    # @param [Boolean] requeue      Should this message be requeued instead of dropping it?
    # @see Bunny::Channel#ack
    # @see Bunny::Channel#nack
    # @see http://rubybunny.info/articles/queues.html Queues and Consumers guide
    def reject(delivery_tag, requeue = false)
      basic_reject(delivery_tag, requeue)
    end

    # Acknowledges a message. Acknowledged messages are completely removed from the queue.
    #
    # @param [Integer] delivery_tag Delivery tag to acknowledge
    # @param [Boolean] multiple (false) Should all unacknowledged messages up to this be acknowledged as well?
    # @see Bunny::Channel#nack
    # @see http://rubybunny.info/articles/queues.html Queues and Consumers guide
    def ack(delivery_tag, multiple = false)
      basic_ack(delivery_tag, multiple)
    end
    alias acknowledge ack

    # Rejects a message. A rejected message can be requeued or
    # dropped by RabbitMQ. This method is similar to {Bunny::Channel#reject} but
    # supports rejecting multiple messages at once, and is usually preferred.
    #
    # @param [Integer] delivery_tag Delivery tag to reject
    # @param [Boolean] requeue      Should this message be requeued instead of dropping it?
    # @param [Boolean] multiple (false) Should all unacknowledged messages up to this be rejected as well?
    # @see Bunny::Channel#ack
    # @see http://rubybunny.info/articles/queues.html Queues and Consumers guide
    def nack(delivery_tag, requeue, multiple = false)
      basic_nack(delivery_tag, requeue, multiple)
    end

    # @endgroup


    def on_error(&block)
      @default_error_handler = block
    end

    #
    # Lower-level API, exposes protocol operations as they are defined in the protocol,
    # without any OO sugar on top, by design.
    #

    # @group Consumer and Message operations (basic.*)

    def basic_publish(payload, exchange, routing_key, opts = {})
      raise_if_no_longer_open!

      exchange_name = if exchange.respond_to?(:name)
                        exchange.name
                      else
                        exchange
                      end

      meta = { :priority => 0, :delivery_mode => 2, :content_type => "application/octet-stream" }.
        merge(opts)

      if @next_publish_seq_no > 0
        @unconfirmed_set.add(@next_publish_seq_no)
        @next_publish_seq_no += 1
      end

      @connection.send_frameset(AMQ::Protocol::Basic::Publish.encode(@id,
                                                                     payload,
                                                                     meta,
                                                                     exchange_name,
                                                                     routing_key,
                                                                     meta[:mandatory],
                                                                     false,
                                                                     @connection.frame_max), self)

      self
    end

    def basic_get(queue, opts = {:ack => true})
      raise_if_no_longer_open!

      @connection.send_frame(AMQ::Protocol::Basic::Get.encode(@id, queue, !opts[:ack]))
      @last_basic_get_response = @continuations.pop

      raise_if_continuation_resulted_in_a_channel_error!
      @last_basic_get_response
    end

    def basic_qos(prefetch_count, global = false)
      raise ArgumentError.new("prefetch count must be a positive integer, given: #{prefetch_count}") if prefetch_count < 0
      raise_if_no_longer_open!

      @connection.send_frame(AMQ::Protocol::Basic::Qos.encode(@id, 0, prefetch_count, global))

      Bunny::Timer.timeout(1, ClientTimeout) do
        @last_basic_qos_ok = @continuations.pop
      end
      raise_if_continuation_resulted_in_a_channel_error!

      @prefetch_count = prefetch_count

      @last_basic_qos_ok
    end

    def basic_recover(requeue)
      raise_if_no_longer_open!

      @connection.send_frame(AMQ::Protocol::Basic::Recover.encode(@id, requeue))
      Bunny::Timer.timeout(1, ClientTimeout) do
        @last_basic_recover_ok = @continuations.pop
      end
      raise_if_continuation_resulted_in_a_channel_error!

      @last_basic_recover_ok
    end

    def basic_reject(delivery_tag, requeue)
      raise_if_no_longer_open!
      @connection.send_frame(AMQ::Protocol::Basic::Reject.encode(@id, delivery_tag, requeue))

      nil
    end

    def basic_ack(delivery_tag, multiple)
      raise_if_no_longer_open!
      @connection.send_frame(AMQ::Protocol::Basic::Ack.encode(@id, delivery_tag, multiple))

      nil
    end

    def basic_nack(delivery_tag, requeue, multiple = false)
      raise_if_no_longer_open!
      @connection.send_frame(AMQ::Protocol::Basic::Nack.encode(@id,
                                                               delivery_tag,
                                                               requeue,
                                                               multiple))

      nil
    end

    def basic_consume(queue, consumer_tag = generate_consumer_tag, no_ack = false, exclusive = false, arguments = nil, &block)
      raise_if_no_longer_open!
      maybe_start_consumer_work_pool!

      queue_name = if queue.respond_to?(:name)
                     queue.name
                   else
                     queue
                   end

      @connection.send_frame(AMQ::Protocol::Basic::Consume.encode(@id,
                                                                  queue_name,
                                                                  consumer_tag,
                                                                  false,
                                                                  no_ack,
                                                                  exclusive,
                                                                  false,
                                                                  arguments))
      # helps avoid race condition between basic.consume-ok and basic.deliver if there are messages
      # in the queue already. MK.
      if consumer_tag && consumer_tag.strip != AMQ::Protocol::EMPTY_STRING
        add_consumer(queue_name, consumer_tag, no_ack, exclusive, arguments, &block)
      end

      Bunny::Timer.timeout(1, ClientTimeout) do
        @last_basic_consume_ok = @continuations.pop
      end
      # covers server-generated consumer tags
      add_consumer(queue_name, @last_basic_consume_ok.consumer_tag, no_ack, exclusive, arguments, &block)

      @last_basic_consume_ok
    end

    def basic_consume_with(consumer)
      raise_if_no_longer_open!
      maybe_start_consumer_work_pool!

      @connection.send_frame(AMQ::Protocol::Basic::Consume.encode(@id,
                                                                  consumer.queue_name,
                                                                  consumer.consumer_tag,
                                                                  false,
                                                                  consumer.no_ack,
                                                                  consumer.exclusive,
                                                                  false,
                                                                  consumer.arguments))

      # helps avoid race condition between basic.consume-ok and basic.deliver if there are messages
      # in the queue already. MK.
      if consumer.consumer_tag && consumer.consumer_tag.strip != AMQ::Protocol::EMPTY_STRING
        register_consumer(consumer.consumer_tag, consumer)
      end

      Bunny::Timer.timeout(1, ClientTimeout) do
        @last_basic_consume_ok = @continuations.pop
      end
      # covers server-generated consumer tags
      register_consumer(@last_basic_consume_ok.consumer_tag, consumer)

      raise_if_continuation_resulted_in_a_channel_error!

      @last_basic_consume_ok
    end

    def basic_cancel(consumer_tag)
      @connection.send_frame(AMQ::Protocol::Basic::Cancel.encode(@id, consumer_tag, false))

      Bunny::Timer.timeout(1, ClientTimeout) do
        @last_basic_cancel_ok = @continuations.pop
      end

      @last_basic_cancel_ok
    end

    # @endgroup


    # @group Queue operations (queue.*)

    def queue_declare(name, opts = {})
      raise_if_no_longer_open!

      @connection.send_frame(AMQ::Protocol::Queue::Declare.encode(@id,
                                                                  name,
                                                                  opts.fetch(:passive, false),
                                                                  opts.fetch(:durable, false),
                                                                  opts.fetch(:exclusive, false),
                                                                  opts.fetch(:auto_delete, false),
                                                                  false,
                                                                  opts[:arguments]))
      @last_queue_declare_ok = @continuations.pop

      raise_if_continuation_resulted_in_a_channel_error!

      @last_queue_declare_ok
    end

    def queue_delete(name, opts = {})
      raise_if_no_longer_open!

      @connection.send_frame(AMQ::Protocol::Queue::Delete.encode(@id,
                                                                 name,
                                                                 opts[:if_unused],
                                                                 opts[:if_empty],
                                                                 false))
      Bunny::Timer.timeout(1, ClientTimeout) do
        @last_queue_delete_ok = @continuations.pop
      end
      raise_if_continuation_resulted_in_a_channel_error!

      @last_queue_delete_ok
    end

    def queue_purge(name, opts = {})
      raise_if_no_longer_open!

      @connection.send_frame(AMQ::Protocol::Queue::Purge.encode(@id, name, false))

      Bunny::Timer.timeout(1, ClientTimeout) do
        @last_queue_purge_ok = @continuations.pop
      end
      raise_if_continuation_resulted_in_a_channel_error!

      @last_queue_purge_ok
    end

    def queue_bind(name, exchange, opts = {})
      raise_if_no_longer_open!

      exchange_name = if exchange.respond_to?(:name)
                        exchange.name
                      else
                        exchange
                      end

      @connection.send_frame(AMQ::Protocol::Queue::Bind.encode(@id,
                                                               name,
                                                               exchange_name,
                                                               opts[:routing_key],
                                                               false,
                                                               opts[:arguments]))
      Bunny::Timer.timeout(1, ClientTimeout) do
        @last_queue_bind_ok = @continuations.pop
      end

      raise_if_continuation_resulted_in_a_channel_error!
      @last_queue_bind_ok
    end

    def queue_unbind(name, exchange, opts = {})
      raise_if_no_longer_open!

      exchange_name = if exchange.respond_to?(:name)
                        exchange.name
                      else
                        exchange
                      end

      @connection.send_frame(AMQ::Protocol::Queue::Unbind.encode(@id,
                                                                 name,
                                                                 exchange_name,
                                                                 opts[:routing_key],
                                                                 opts[:arguments]))
      Bunny::Timer.timeout(1, ClientTimeout) do
        @last_queue_unbind_ok = @continuations.pop
      end

      raise_if_continuation_resulted_in_a_channel_error!
      @last_queue_unbind_ok
    end

    # @endgroup


    # @group Exchange operations (exchange.*)

    def exchange_declare(name, type, opts = {})
      raise_if_no_longer_open!

      @connection.send_frame(AMQ::Protocol::Exchange::Declare.encode(@id,
                                                                     name,
                                                                     type.to_s,
                                                                     opts.fetch(:passive, false),
                                                                     opts.fetch(:durable, false),
                                                                     opts.fetch(:auto_delete, false),
                                                                     false,
                                                                     false,
                                                                     opts[:arguments]))
      Bunny::Timer.timeout(1, ClientTimeout) do
        @last_exchange_declare_ok = @continuations.pop
      end

      raise_if_continuation_resulted_in_a_channel_error!
      @last_exchange_declare_ok
    end

    def exchange_delete(name, opts = {})
      raise_if_no_longer_open!

      @connection.send_frame(AMQ::Protocol::Exchange::Delete.encode(@id,
                                                                    name,
                                                                    opts[:if_unused],
                                                                    false))
      Bunny::Timer.timeout(1, ClientTimeout) do
        @last_exchange_delete_ok = @continuations.pop
      end

      raise_if_continuation_resulted_in_a_channel_error!
      @last_exchange_delete_ok
    end

    def exchange_bind(source, destination, opts = {})
      raise_if_no_longer_open!

      source_name = if source.respond_to?(:name)
                      source.name
                    else
                      source
                    end

      destination_name = if destination.respond_to?(:name)
                           destination.name
                         else
                           destination
                         end

      @connection.send_frame(AMQ::Protocol::Exchange::Bind.encode(@id,
                                                                  destination_name,
                                                                  source_name,
                                                                  opts[:routing_key],
                                                                  false,
                                                                  opts[:arguments]))
      Bunny::Timer.timeout(1, ClientTimeout) do
        @last_exchange_bind_ok = @continuations.pop
      end

      raise_if_continuation_resulted_in_a_channel_error!
      @last_exchange_bind_ok
    end

    def exchange_unbind(source, destination, opts = {})
      raise_if_no_longer_open!

      source_name = if source.respond_to?(:name)
                      source.name
                    else
                      source
                    end

      destination_name = if destination.respond_to?(:name)
                           destination.name
                         else
                           destination
                         end

      @connection.send_frame(AMQ::Protocol::Exchange::Unbind.encode(@id,
                                                                    destination_name,
                                                                    source_name,
                                                                    opts[:routing_key],
                                                                    false,
                                                                    opts[:arguments]))
      Bunny::Timer.timeout(1, ClientTimeout) do
        @last_exchange_unbind_ok = @continuations.pop
      end

      raise_if_continuation_resulted_in_a_channel_error!
      @last_exchange_unbind_ok
    end

    # @endgroup



    # @group Flow control (channel.*)

    def channel_flow(active)
      raise_if_no_longer_open!

      @connection.send_frame(AMQ::Protocol::Channel::Flow.encode(@id, active))
      Bunny::Timer.timeout(1, ClientTimeout) do
        @last_channel_flow_ok = @continuations.pop
      end
      raise_if_continuation_resulted_in_a_channel_error!

      @last_channel_flow_ok
    end

    # @endgroup



    # @group Transactions (tx.*)

    # Puts the channel into transaction mode (starts a transaction)
    def tx_select
      raise_if_no_longer_open!

      @connection.send_frame(AMQ::Protocol::Tx::Select.encode(@id))
      Bunny::Timer.timeout(1, ClientTimeout) do
        @last_tx_select_ok = @continuations.pop
      end
      raise_if_continuation_resulted_in_a_channel_error!

      @last_tx_select_ok
    end

    # Commits current transaction
    def tx_commit
      raise_if_no_longer_open!

      @connection.send_frame(AMQ::Protocol::Tx::Commit.encode(@id))
      Bunny::Timer.timeout(1, ClientTimeout) do
        @last_tx_commit_ok = @continuations.pop
      end
      raise_if_continuation_resulted_in_a_channel_error!

      @last_tx_commit_ok
    end

    # Rolls back current transaction
    def tx_rollback
      raise_if_no_longer_open!

      @connection.send_frame(AMQ::Protocol::Tx::Rollback.encode(@id))
      Bunny::Timer.timeout(1, ClientTimeout) do
        @last_tx_rollback_ok = @continuations.pop
      end
      raise_if_continuation_resulted_in_a_channel_error!

      @last_tx_rollback_ok
    end

    # @endgroup



    # @group Publisher Confirms (confirm.*)

    # @return [Boolean] true if this channel has Publisher Confirms enabled, false otherwise
    def using_publisher_confirmations?
      @next_publish_seq_no > 0
    end

    # Enables publisher confirms
    def confirm_select(callback=nil)
      raise_if_no_longer_open!

      if @next_publish_seq_no == 0
        @confirms_continuations = ::Queue.new
        @unconfirmed_set        = Set.new
        @nacked_set             = Set.new
        @next_publish_seq_no    = 1
      end

      @confirms_callback = callback

      @connection.send_frame(AMQ::Protocol::Confirm::Select.encode(@id, false))
      Bunny::Timer.timeout(1, ClientTimeout) do
        @last_confirm_select_ok = @continuations.pop
      end
      raise_if_continuation_resulted_in_a_channel_error!
      @last_confirm_select_ok
    end

    # Blocks calling thread until confirms are received for all
    # currently unacknowledged published messages
    def wait_for_confirms
      @only_acks_received = true
      @confirms_continuations.pop

      @only_acks_received
    end

    # @endgroup


    # @group Misc

    # Synchronizes given block using this channel's mutex.
    # @api public
    def synchronize(&block)
      @publishing_mutex.synchronize(&block)
    end

    # Unique string supposed to be used as a consumer tag.
    #
    # @return [String]  Unique string.
    # @api plugin
    def generate_consumer_tag(name = "bunny")
      "#{name}-#{Time.now.to_i * 1000}-#{Kernel.rand(999_999_999_999)}"
    end

    # @endgroup


    #
    # Recovery
    #

    # Recovers basic.qos setting, exchanges, queues and consumers. Used by the Automatic Network Failure
    # Recovery feature.
    #
    # @api plugin
    def recover_from_network_failure
      # puts "Recovering channel #{@id} from network failure..."
      recover_prefetch_setting
      recover_exchanges
      # this includes recovering bindings
      recover_queues
      recover_consumers
    end

    # Recovers basic.qos setting. Used by the Automatic Network Failure
    # Recovery feature.
    #
    # @api plugin
    def recover_prefetch_setting
      basic_qos(@prefetch_count) if @prefetch_count
    end

    # Recovers exchanges. Used by the Automatic Network Failure
    # Recovery feature.
    #
    # @api plugin
    def recover_exchanges
      @exchanges.values.dup.each do |x|
        x.recover_from_network_failure
      end
    end

    # Recovers queues and bindings. Used by the Automatic Network Failure
    # Recovery feature.
    #
    # @api plugin
    def recover_queues
      @queues.values.dup.each do |q|
        q.recover_from_network_failure
      end
    end

    # Recovers consumers. Used by the Automatic Network Failure
    # Recovery feature.
    #
    # @api plugin
    def recover_consumers
      unless @consumers.empty?
        @work_pool = ConsumerWorkPool.new(@work_pool.size)
        @work_pool.start
      end
      @consumers.values.dup.each do |c|
        c.recover_from_network_failure
      end
    end



    #
    # Implementation
    #

    # @private
    def register_consumer(consumer_tag, consumer)
      @consumer_mutex.synchronize do
        @consumers[consumer_tag] = consumer
      end
    end

    # @private
    def add_consumer(queue, consumer_tag, no_ack, exclusive, arguments, &block)
      @consumer_mutex.synchronize do
        c = Consumer.new(self, queue, consumer_tag, no_ack, exclusive, arguments)
        c.on_delivery(&block) if block
        @consumers[consumer_tag] = c
      end
    end

    # @private
    def handle_method(method)
      # puts "Channel#handle_frame on channel #{@id}: #{method.inspect}"
      case method
      when AMQ::Protocol::Queue::DeclareOk then
        @continuations.push(method)
      when AMQ::Protocol::Queue::DeleteOk then
        @continuations.push(method)
      when AMQ::Protocol::Queue::PurgeOk then
        @continuations.push(method)
      when AMQ::Protocol::Queue::BindOk then
        @continuations.push(method)
      when AMQ::Protocol::Queue::UnbindOk then
        @continuations.push(method)
      when AMQ::Protocol::Exchange::BindOk then
        @continuations.push(method)
      when AMQ::Protocol::Exchange::UnbindOk then
        @continuations.push(method)
      when AMQ::Protocol::Exchange::DeclareOk then
        @continuations.push(method)
      when AMQ::Protocol::Exchange::DeleteOk then
        @continuations.push(method)
      when AMQ::Protocol::Basic::QosOk then
        @continuations.push(method)
      when AMQ::Protocol::Basic::RecoverOk then
        @continuations.push(method)
      when AMQ::Protocol::Channel::FlowOk then
        @continuations.push(method)
      when AMQ::Protocol::Basic::ConsumeOk then
        @continuations.push(method)
      when AMQ::Protocol::Basic::Cancel then
        if consumer = @consumers[method.consumer_tag]
          consumer.handle_cancellation(method)
        end

        @consumers.delete(method.consumer_tag)
      when AMQ::Protocol::Basic::CancelOk then
        @continuations.push(method)
        @consumers.delete(method.consumer_tag)
      when AMQ::Protocol::Tx::SelectOk, AMQ::Protocol::Tx::CommitOk, AMQ::Protocol::Tx::RollbackOk then
        @continuations.push(method)
      when AMQ::Protocol::Tx::SelectOk then
        @continuations.push(method)
      when AMQ::Protocol::Confirm::SelectOk then
        @continuations.push(method)
      when AMQ::Protocol::Basic::Ack then
        handle_ack_or_nack(method.delivery_tag, method.multiple, false)
      when AMQ::Protocol::Basic::Nack then
        handle_ack_or_nack(method.delivery_tag, method.multiple, true)
      when AMQ::Protocol::Channel::Close then
        # puts "Exception on channel #{@id}: #{method.reply_code} #{method.reply_text}"
        closed!
        @connection.send_frame(AMQ::Protocol::Channel::CloseOk.encode(@id))

        @last_channel_error = instantiate_channel_level_exception(method)
        @continuations.push(method)
      when AMQ::Protocol::Channel::CloseOk then
        @continuations.push(method)
      else
        raise "Do not know how to handle #{method.inspect} in Bunny::Channel#handle_method"
      end
    end

    # @private
    def handle_basic_get_ok(basic_get_ok, properties, content)
      @continuations.push([basic_get_ok, properties, content])
    end

    # @private
    def handle_basic_get_empty(basic_get_empty)
      @continuations.push([nil, nil, nil])
    end

    # @private
    def handle_frameset(basic_deliver, properties, content)
      consumer = @consumers[basic_deliver.consumer_tag]
      if consumer
        @work_pool.submit do
          consumer.call(DeliveryInfo.new(basic_deliver), MessageProperties.new(properties), content)
        end
      else
        # TODO: log it
        puts "[warning] No consumer for tag #{basic_deliver.consumer_tag}"
      end
    end

    # @private
    def handle_basic_return(basic_return, properties, content)
      x = find_exchange(basic_return.exchange)

      if x
        x.handle_return(ReturnInfo.new(basic_return), MessageProperties.new(properties), content)
      else
        # TODO: log a warning
      end
    end

    # @private
    def handle_ack_or_nack(delivery_tag, multiple, nack)
      if nack
        cloned_set = @unconfirmed_set.clone
        if multiple
          cloned_set.keep_if { |i| i <= delivery_tag }
          @nacked_set.merge(cloned_set)
        else
          @nacked_set.add(delivery_tag)
        end
      end
 
      if multiple
        @unconfirmed_set.delete_if { |i| i <= delivery_tag }
      else
        @unconfirmed_set.delete(delivery_tag)
      end

      @unconfirmed_set_mutex.synchronize do
        @only_acks_received = (@only_acks_received && !nack)

        @confirms_continuations.push(true) if @unconfirmed_set.empty?

        @confirms_callback.call(delivery_tag, multiple, nack) if @confirms_callback
      end
    end

    # Starts consumer work pool. Lazily called by #basic_consume to avoid creating new threads
    # that won't do any real work for channels that do not register consumers (e.g. only used for
    # publishing). MK.
    # @private
    def maybe_start_consumer_work_pool!
      @work_pool.start unless @work_pool.started?
    end

    # @private
    def maybe_pause_consumer_work_pool!
      @work_pool.pause if @work_pool && @work_pool.started?
    end

    # @private
    def maybe_kill_consumer_work_pool!
      @work_pool.kill if @work_pool && @work_pool.started?
    end

    # @private
    def read_next_frame(options = {})
      @connection.read_next_frame(options = {})
    end

    # @private
    def deregister_queue(queue)
      @queues.delete(queue.name)
    end

    # @private
    def deregister_queue_named(name)
      @queues.delete(name)
    end

    # @private
    def register_queue(queue)
      @queues[queue.name] = queue
    end

    # @private
    def find_queue(name)
      @queues[name]
    end

    # @private
    def deregister_exchange(exchange)
      @exchanges.delete(exchange.name)
    end

    # @private
    def register_exchange(exchange)
      @exchanges[exchange.name] = exchange
    end

    # @private
    def find_exchange(name)
      @exchanges[name]
    end

    protected

    # @private
    def closed!
      @status = :closed
      @work_pool.shutdown
      @connection.release_channel_id(@id)
    end

    # @private
    def instantiate_channel_level_exception(frame)
      case frame
      when AMQ::Protocol::Channel::Close then
        klass = case frame.reply_code
                when 403 then
                  AccessRefused
                when 404 then
                  NotFound
                when 405 then
                  ResourceLocked
                when 406 then
                  PreconditionFailed
                else
                  ChannelLevelException
                end

        klass.new(frame.reply_text, self, frame)
      end
    end

    # @private
    def raise_if_continuation_resulted_in_a_channel_error!
      raise @last_channel_error if @last_channel_error
    end

    # @private
    def raise_if_no_longer_open!
      raise ChannelAlreadyClosed.new("cannot use a channel that was already closed! Channel id: #{@id}", self) if closed?
    end
  end
end
