# -*- coding: utf-8 -*-
require "thread"
require "monitor"
require "set"

require "bunny/concurrent/atomic_fixnum"
require "bunny/consumer_work_pool"

require "bunny/exchange"
require "bunny/queue"

require "bunny/delivery_info"
require "bunny/return_info"
require "bunny/message_properties"

if defined?(JRUBY_VERSION)
  require "bunny/concurrent/linked_continuation_queue"
else
  require "bunny/concurrent/continuation_queue"
end

module Bunny
  # ## Channels in RabbitMQ
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
  #     conn = Bunny.new
  #     conn.start
  #
  #     ch   = conn.create_channel
  #
  # This will automatically allocate a channel id.
  #
  # ## Closing Channels
  #
  # Channels are closed via {Bunny::Channel#close}. Channels that get a channel-level exception are
  # closed, too. Closed channels can no longer be used. Attempts to use them will raise
  # {Bunny::ChannelAlreadyClosed}.
  #
  #     ch = conn.create_channel
  #     ch.close
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
  # @see http://rubybunny.info/articles/queues.html Queues and Consumers
  # @see http://rubybunny.info/articles/exchanges.html Exchanges and Publishing
  # @see http://rubybunny.info/articles/error_handling.html Error Handling and Recovery Guide
  class Channel

    #
    # API
    #

    # @return [Integer] Channel id
    attr_accessor :id
    # @return [Bunny::Session] AMQP connection this channel was opened on
    attr_reader :connection
    # @return [Symbol] Channel status (:opening, :open, :closed)
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

    # @return [Integer] active basic.qos prefetch value
    attr_reader :prefetch_count
    # @return [Integer] active basic.qos prefetch global mode
    attr_reader :prefetch_global

    DEFAULT_CONTENT_TYPE = "application/octet-stream".freeze
    SHORTSTR_LIMIT = 255

    # @param [Bunny::Session] connection AMQP 0.9.1 connection
    # @param [Integer] id Channel id, pass nil to make Bunny automatically allocate it
    # @param [Bunny::ConsumerWorkPool] work_pool Thread pool for delivery processing, by default of size 1
    def initialize(connection = nil, id = nil, work_pool = ConsumerWorkPool.new(1))
      @connection = connection
      @logger     = connection.logger
      @id         = id || @connection.next_channel_id
      @status     = :opening

      @connection.register_channel(self)

      @queues     = Hash.new
      @exchanges  = Hash.new
      @consumers  = Hash.new
      @work_pool  = work_pool

      # synchronizes frameset delivery. MK.
      @publishing_mutex = @connection.mutex_impl.new
      @consumer_mutex   = @connection.mutex_impl.new

      @queue_mutex    = @connection.mutex_impl.new
      @exchange_mutex = @connection.mutex_impl.new

      @unconfirmed_set_mutex = @connection.mutex_impl.new

      self.reset_continuations

      # threads awaiting on continuations. Used to unblock
      # them when network connection goes down so that busy loops
      # that perform synchronous operations can work. MK.
      @threads_waiting_on_continuations           = Set.new
      @threads_waiting_on_confirms_continuations  = Set.new
      @threads_waiting_on_basic_get_continuations = Set.new

      @next_publish_seq_no = 0
      @delivery_tag_offset = 0

      @recoveries_counter = Bunny::Concurrent::AtomicFixnum.new(0)
      @uncaught_exception_handler = Proc.new do |e, consumer|
        @logger.error "Uncaught exception from consumer #{consumer.to_s}: #{e.inspect} @ #{e.backtrace[0]}"
      end
    end

    attr_reader :recoveries_counter

    # @private
    def wait_on_continuations_timeout
      @connection.transport_write_timeout
    end

    # Opens the channel and resets its internal state
    # @return [Bunny::Channel] Self
    # @api public
    def open
      @threads_waiting_on_continuations           = Set.new
      @threads_waiting_on_confirms_continuations  = Set.new
      @threads_waiting_on_basic_get_continuations = Set.new

      @connection.open_channel(self)
      # clear last channel error
      @last_channel_error = nil

      @status = :open

      self
    end

    # Closes the channel. Closed channels can no longer be used (this includes associated
    # {Bunny::Queue}, {Bunny::Exchange} and {Bunny::Consumer} instances.
    # @api public
    def close
      @connection.close_channel(self)
      @status = :closed
      @work_pool.shutdown
      maybe_kill_consumer_work_pool!
    end

    # @return [Boolean] true if this channel is open, false otherwise
    # @api public
    def open?
      @status == :open
    end

    # @return [Boolean] true if this channel is closed (manually or because of an exception), false otherwise
    # @api public
    def closed?
      @status == :closed
    end

    def to_s
      oid = ("0x%x" % (self.object_id << 1))
      "<#{self.class.name}:#{oid} number=#{@channel.id} @open=#{open?} connection=#{@connection.to_s}>"
    end

    def inspect
      to_s
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
    # @api public
    def fanout(name, opts = {})
      find_exchange(name) || Exchange.new(self, :fanout, name, opts)
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
    # @api public
    def direct(name, opts = {})
      find_exchange(name) || Exchange.new(self, :direct, name, opts)
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
    # @api public
    def topic(name, opts = {})
      find_exchange(name) || Exchange.new(self, :topic, name, opts)
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
    # @api public
    def headers(name, opts = {})
      find_exchange(name) || Exchange.new(self, :headers, name, opts)
    end

    # Provides access to the default exchange
    # @see http://rubybunny.info/articles/exchanges.html Exchanges and Publishing guide
    # @api public
    def default_exchange
      Exchange.default(self)
    end

    # Declares a headers exchange or looks it up in the cache of previously
    # declared exchanges.
    #
    # @param [String] name Exchange name
    # @param [Hash] opts Exchange parameters
    #
    # @option opts [String,Symbol] :type (:direct) Exchange type, e.g. :fanout or "x-consistent-hash"
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

    # Declares a queue or looks it up in the per-channel cache.
    #
    # @param  [String] name  Queue name. Pass an empty string to declare a server-named queue (make RabbitMQ generate a unique name).
    # @param  [Hash]   opts  Queue properties and other options
    #
    # @option opts [Boolean] :durable (false) Should this queue be durable?
    # @option opts [Boolean] :auto-delete (false) Should this queue be automatically deleted when the last consumer disconnects?
    # @option opts [Boolean] :exclusive (false) Should this queue be exclusive (only can be used by this connection, removed when the connection is closed)?
    # @option opts [Boolean] :arguments ({}) Additional optional arguments (typically used by RabbitMQ extensions and plugins)
    #
    # @return [Bunny::Queue] Queue that was declared or looked up in the cache
    # @see http://rubybunny.info/articles/queues.html Queues and Consumers guide
    # @see http://rubybunny.info/articles/extensions.html RabbitMQ Extensions guide
    # @api public
    def queue(name = AMQ::Protocol::EMPTY_STRING, opts = {})
      q = find_queue(name) || Bunny::Queue.new(self, name, opts)

      register_queue(q)
    end

    # Declares a new server-named queue that is automatically deleted when the
    # connection is closed.
    #
    # @return [Bunny::Queue] Queue that was declared
    # @see #queue
    # @api public
    def temporary_queue(opts = {})
      queue("", opts.merge(:exclusive => true))
    end

    # @endgroup


    # @group QoS and Flow Control

    # Flow control. When set to false, RabbitMQ will stop delivering messages on this
    # channel.
    #
    # @param [Boolean] active Should messages to consumers on this channel be delivered?
    # @api public
    def flow(active)
      channel_flow(active)
    end

    # Tells RabbitMQ to redeliver unacknowledged messages
    # @api public
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
    # @api public
    def reject(delivery_tag, requeue = false)
      basic_reject(delivery_tag.to_i, requeue)
    end

    # Acknowledges a message. Acknowledged messages are completely removed from the queue.
    #
    # @param [Integer] delivery_tag Delivery tag to acknowledge
    # @param [Boolean] multiple (false) Should all unacknowledged messages up to this be acknowledged as well?
    # @see Bunny::Channel#nack
    # @see http://rubybunny.info/articles/queues.html Queues and Consumers guide
    # @api public
    def ack(delivery_tag, multiple = false)
      basic_ack(delivery_tag.to_i, multiple)
    end
    alias acknowledge ack

    # Rejects a message. A rejected message can be requeued or
    # dropped by RabbitMQ. This method is similar to {Bunny::Channel#reject} but
    # supports rejecting multiple messages at once, and is usually preferred.
    #
    # @param [Integer] delivery_tag Delivery tag to reject
    # @param [Boolean] multiple (false) Should all unacknowledged messages up to this be rejected as well?
    # @param [Boolean] requeue  (false) Should this message be requeued instead of dropping it?
    # @see Bunny::Channel#ack
    # @see http://rubybunny.info/articles/queues.html Queues and Consumers guide
    # @api public
    def nack(delivery_tag, multiple = false, requeue = false)
      basic_nack(delivery_tag.to_i, multiple, requeue)
    end

    # @endgroup

    #
    # Lower-level API, exposes protocol operations as they are defined in the protocol,
    # without any OO sugar on top, by design.
    #

    # @group Consumer and Message operations (basic.*)

    # Publishes a message using basic.publish AMQP 0.9.1 method.
    #
    # @param [String] payload Message payload. It will never be modified by Bunny or RabbitMQ in any way.
    # @param [String] exchange Exchange to publish to
    # @param [String] routing_key Routing key
    # @param [Hash] opts Publishing options
    #
    # @option opts [Boolean] :persistent Should the message be persisted to disk?
    # @option opts [Boolean] :mandatory Should the message be returned if it cannot be routed to any queue?
    # @option opts [Integer] :timestamp A timestamp associated with this message
    # @option opts [Integer] :expiration Expiration time after which the message will be deleted
    # @option opts [String] :type Message type, e.g. what type of event or command this message represents. Can be any string
    # @option opts [String] :reply_to Queue name other apps should send the response to
    # @option opts [String] :content_type Message content type (e.g. application/json)
    # @option opts [String] :content_encoding Message content encoding (e.g. gzip)
    # @option opts [String] :correlation_id Message correlated to this one, e.g. what request this message is a reply for
    # @option opts [Integer] :priority Message priority, 0 to 9. Not used by RabbitMQ, only applications
    # @option opts [String] :message_id Any message identifier
    # @option opts [String] :user_id Optional user ID. Verified by RabbitMQ against the actual connection username
    # @option opts [String] :app_id Optional application ID
    #
    # @return [Bunny::Channel] Self
    # @api public
    def basic_publish(payload, exchange, routing_key, opts = {})
      raise_if_no_longer_open!
      raise ArgumentError, "routing key cannot be longer than #{SHORTSTR_LIMIT} characters" if routing_key && routing_key.size > SHORTSTR_LIMIT

      exchange_name = if exchange.respond_to?(:name)
                        exchange.name
                      else
                        exchange
                      end

      mode = if opts.fetch(:persistent, true)
               2
             else
               1
             end

      opts[:delivery_mode] ||= mode
      opts[:content_type]  ||= DEFAULT_CONTENT_TYPE
      opts[:priority]      ||= 0

      if @next_publish_seq_no > 0
        @unconfirmed_set_mutex.synchronize do
          @unconfirmed_set.add(@next_publish_seq_no)
          @next_publish_seq_no += 1
        end
      end

      frames = AMQ::Protocol::Basic::Publish.encode(@id,
        payload,
        opts,
        exchange_name,
        routing_key,
        opts[:mandatory],
        false,
        @connection.frame_max)
      @connection.send_frameset(frames, self)

      self
    end

    # Synchronously fetches a message from the queue, if there are any. This method is
    # for cases when the convenience of synchronous operations is more important than
    # throughput.
    #
    # @param [String] queue Queue name
    # @param [Hash] opts Options
    #
    # @option opts [Boolean] :ack (true) [DEPRECATED] Use :manual_ack instead
    # @option opts [Boolean] :manual_ack (true) Will this message be acknowledged manually?
    #
    # @return [Array] A triple of delivery info, message properties and message content
    #
    # @example Using Bunny::Channel#basic_get with manual acknowledgements
    #   conn = Bunny.new
    #   conn.start
    #   ch   = conn.create_channel
    #   # here we assume the queue already exists and has messages
    #   delivery_info, properties, payload = ch.basic_get("bunny.examples.queue1", :manual_ack => true)
    #   ch.acknowledge(delivery_info.delivery_tag)
    # @see Bunny::Queue#pop
    # @see http://rubybunny.info/articles/queues.html Queues and Consumers guide
    # @api public
    def basic_get(queue, opts = {:manual_ack => true})
      raise_if_no_longer_open!

      unless opts[:ack].nil?
        warn "[DEPRECATION] `:ack` is deprecated.  Please use `:manual_ack` instead."
        opts[:manual_ack] = opts[:ack]
      end

      @connection.send_frame(AMQ::Protocol::Basic::Get.encode(@id, queue, !(opts[:manual_ack])))
      # this is a workaround for the edge case when basic_get is called in a tight loop
      # and network goes down we need to perform recovery. The problem is, basic_get will
      # keep blocking the thread that calls it without clear way to constantly unblock it
      # from the network activity loop (where recovery happens) with the current continuations
      # implementation (and even more correct and convenient ones, such as wait/notify, should
      # we implement them). So we return a triple of nils immediately which apps should be
      # able to handle anyway as "got no message, no need to act". MK.
      last_basic_get_response = if @connection.open?
                                  begin
                                    wait_on_basic_get_continuations
                                  rescue Timeout::Error => e
                                    raise_if_continuation_resulted_in_a_channel_error!
                                    raise e
                                  end
                                else
                                  [nil, nil, nil]
                                end

      raise_if_continuation_resulted_in_a_channel_error!
      last_basic_get_response
    end

    # prefetch_count is of type short in the protocol. MK.
    MAX_PREFETCH_COUNT = (2 ** 16) - 1

    # Controls message delivery rate using basic.qos AMQP 0.9.1 method.
    #
    # @param [Integer] prefetch_count How many messages can consumers on this channel be given at a time
    #                                 (before they have to acknowledge or reject one of the earlier received messages)
    # @param [Boolean] global
    #   Whether to use global mode for prefetch:
    #   - +false+: per-consumer
    #   - +true+:  per-channel
    #   Note that the default value (+false+) hasn't actually changed, but
    #   previous documentation described that as meaning per-channel and
    #   unsupported in RabbitMQ, whereas it now actually appears to mean
    #   per-consumer and supported
    #   (https://www.rabbitmq.com/consumer-prefetch.html).
    # @return [AMQ::Protocol::Basic::QosOk] RabbitMQ response
    # @see Bunny::Channel#prefetch
    # @see http://rubybunny.info/articles/queues.html Queues and Consumers guide
    # @api public
    def basic_qos(count, global = false)
      raise ArgumentError.new("prefetch count must be a positive integer, given: #{count}") if count < 0
      raise ArgumentError.new("prefetch count must be no greater than #{MAX_PREFETCH_COUNT}, given: #{count}") if count > MAX_PREFETCH_COUNT
      raise_if_no_longer_open!

      @connection.send_frame(AMQ::Protocol::Basic::Qos.encode(@id, 0, count, global))

      Bunny::Timeout.timeout(wait_on_continuations_timeout, ClientTimeout) do
        @last_basic_qos_ok = wait_on_continuations
      end
      raise_if_continuation_resulted_in_a_channel_error!

      @prefetch_count  = count
      @prefetch_global = global

      @last_basic_qos_ok
    end
    alias prefetch basic_qos

    # Redeliver unacknowledged messages
    #
    # @param [Boolean] requeue Should messages be requeued?
    # @return [AMQ::Protocol::Basic::RecoverOk] RabbitMQ response
    # @api public
    def basic_recover(requeue)
      raise_if_no_longer_open!

      @connection.send_frame(AMQ::Protocol::Basic::Recover.encode(@id, requeue))
      Bunny::Timeout.timeout(wait_on_continuations_timeout, ClientTimeout) do
        @last_basic_recover_ok = wait_on_continuations
      end
      raise_if_continuation_resulted_in_a_channel_error!

      @last_basic_recover_ok
    end

    # Rejects or requeues a message.
    #
    # @param [Integer] delivery_tag Delivery tag obtained from delivery info
    # @param [Boolean] requeue Should the message be requeued?
    # @return [NilClass] nil
    #
    # @example Requeue a message
    #   conn  = Bunny.new
    #   conn.start
    #
    #   ch    = conn.create_channel
    #   q.subscribe do |delivery_info, properties, payload|
    #     # requeue the message
    #     ch.basic_reject(delivery_info.delivery_tag, true)
    #   end
    #
    # @example Reject a message
    #   conn  = Bunny.new
    #   conn.start
    #
    #   ch    = conn.create_channel
    #   q.subscribe do |delivery_info, properties, payload|
    #     # reject the message
    #     ch.basic_reject(delivery_info.delivery_tag, false)
    #   end
    #
    # @example Requeue a message fetched via basic.get
    #   conn  = Bunny.new
    #   conn.start
    #
    #   ch    = conn.create_channel
    #   # we assume the queue exists and has messages
    #   delivery_info, properties, payload = ch.basic_get("bunny.examples.queue3", :manual_ack => true)
    #   ch.basic_reject(delivery_info.delivery_tag, true)
    #
    # @see Bunny::Channel#basic_nack
    # @see http://rubybunny.info/articles/queues.html Queues and Consumers guide
    # @api public
    def basic_reject(delivery_tag, requeue = false)
      guarding_against_stale_delivery_tags(delivery_tag) do
        raise_if_no_longer_open!
        @connection.send_frame(AMQ::Protocol::Basic::Reject.encode(@id, delivery_tag, requeue))

        nil
      end
    end

    # Acknowledges a delivery (message).
    #
    # @param [Integer] delivery_tag Delivery tag obtained from delivery info
    # @param [Boolean] multiple Should all deliveries up to this one be acknowledged?
    # @return [NilClass] nil
    #
    # @example Ack a message
    #   conn  = Bunny.new
    #   conn.start
    #
    #   ch    = conn.create_channel
    #   q.subscribe do |delivery_info, properties, payload|
    #     # requeue the message
    #     ch.basic_ack(delivery_info.delivery_tag.to_i)
    #   end
    #
    # @example Ack a message fetched via basic.get
    #   conn  = Bunny.new
    #   conn.start
    #
    #   ch    = conn.create_channel
    #   # we assume the queue exists and has messages
    #   delivery_info, properties, payload = ch.basic_get("bunny.examples.queue3", :manual_ack => true)
    #   ch.basic_ack(delivery_info.delivery_tag.to_i)
    #
    # @example Ack multiple messages fetched via basic.get
    #   conn  = Bunny.new
    #   conn.start
    #
    #   ch    = conn.create_channel
    #   # we assume the queue exists and has messages
    #   _, _, payload1 = ch.basic_get("bunny.examples.queue3", :manual_ack => true)
    #   _, _, payload2 = ch.basic_get("bunny.examples.queue3", :manual_ack => true)
    #   delivery_info, properties, payload3 = ch.basic_get("bunny.examples.queue3", :manual_ack => true)
    #   # ack all fetched messages up to payload3
    #   ch.basic_ack(delivery_info.delivery_tag.to_i, true)
    #
    # @see http://rubybunny.info/articles/queues.html Queues and Consumers guide
    # @api public
    def basic_ack(delivery_tag, multiple = false)
      guarding_against_stale_delivery_tags(delivery_tag) do
        raise_if_no_longer_open!
        @connection.send_frame(AMQ::Protocol::Basic::Ack.encode(@id, delivery_tag, multiple))

        nil
      end
    end

    # Rejects or requeues messages just like {Bunny::Channel#basic_reject} but can do so
    # with multiple messages at once.
    #
    # @param [Integer] delivery_tag Delivery tag obtained from delivery info
    # @param [Boolean] requeue Should the message be requeued?
    # @param [Boolean] multiple Should all deliveries up to this one be rejected/requeued?
    # @return [NilClass] nil
    #
    # @example Requeue a message
    #   conn  = Bunny.new
    #   conn.start
    #
    #   ch    = conn.create_channel
    #   q.subscribe do |delivery_info, properties, payload|
    #     # requeue the message
    #     ch.basic_nack(delivery_info.delivery_tag, false, true)
    #   end
    #
    # @example Reject a message
    #   conn  = Bunny.new
    #   conn.start
    #
    #   ch    = conn.create_channel
    #   q.subscribe do |delivery_info, properties, payload|
    #     # requeue the message
    #     ch.basic_nack(delivery_info.delivery_tag)
    #   end
    #
    # @example Requeue a message fetched via basic.get
    #   conn  = Bunny.new
    #   conn.start
    #
    #   ch    = conn.create_channel
    #   # we assume the queue exists and has messages
    #   delivery_info, properties, payload = ch.basic_get("bunny.examples.queue3", :manual_ack => true)
    #   ch.basic_nack(delivery_info.delivery_tag, false, true)
    #
    #
    # @example Requeue multiple messages fetched via basic.get
    #   conn  = Bunny.new
    #   conn.start
    #
    #   ch    = conn.create_channel
    #   # we assume the queue exists and has messages
    #   _, _, payload1 = ch.basic_get("bunny.examples.queue3", :manual_ack => true)
    #   _, _, payload2 = ch.basic_get("bunny.examples.queue3", :manual_ack => true)
    #   delivery_info, properties, payload3 = ch.basic_get("bunny.examples.queue3", :manual_ack => true)
    #   # requeue all fetched messages up to payload3
    #   ch.basic_nack(delivery_info.delivery_tag, true, true)
    #
    # @see http://rubybunny.info/articles/queues.html Queues and Consumers guide
    # @see http://rubybunny.info/articles/extensions.html RabbitMQ Extensions guide
    # @api public
    def basic_nack(delivery_tag, multiple = false, requeue = false)
      guarding_against_stale_delivery_tags(delivery_tag) do
        raise_if_no_longer_open!
        @connection.send_frame(AMQ::Protocol::Basic::Nack.encode(@id,
                                                                 delivery_tag,
                                                                 multiple,
                                                                 requeue))

        nil
      end
    end

    # Registers a consumer for queue. Delivered messages will be handled with the block
    # provided to this method.
    #
    # @param [String, Bunny::Queue] queue Queue to consume from
    # @param [String] consumer_tag Consumer tag (unique identifier), generated by Bunny by default
    # @param [Boolean] no_ack (false) If true, delivered messages will be automatically acknowledged.
    #                                 If false, manual acknowledgements will be necessary.
    # @param [Boolean] exclusive (false) Should this consumer be exclusive?
    # @param [Hash] arguments (nil) Optional arguments that may be used by RabbitMQ extensions, etc
    #
    # @return [AMQ::Protocol::Basic::ConsumeOk] RabbitMQ response
    # @see http://rubybunny.info/articles/queues.html Queues and Consumers guide
    # @api public
    def basic_consume(queue, consumer_tag = generate_consumer_tag, no_ack = false, exclusive = false, arguments = nil, &block)
      raise_if_no_longer_open!
      maybe_start_consumer_work_pool!

      queue_name = if queue.respond_to?(:name)
                     queue.name
                   else
                     queue
                   end

      # helps avoid race condition between basic.consume-ok and basic.deliver if there are messages
      # in the queue already. MK.
      if consumer_tag && consumer_tag.strip != AMQ::Protocol::EMPTY_STRING
        add_consumer(queue_name, consumer_tag, no_ack, exclusive, arguments, &block)
      end

      @connection.send_frame(AMQ::Protocol::Basic::Consume.encode(@id,
          queue_name,
          consumer_tag,
          false,
          no_ack,
          exclusive,
          false,
          arguments))

      begin
        Bunny::Timeout.timeout(wait_on_continuations_timeout, ClientTimeout) do
          @last_basic_consume_ok = wait_on_continuations
        end
      rescue Exception => e
        # if basic.consume-ok never arrives, unregister the proactively
        # registered consumer. MK.
        unregister_consumer(@last_basic_consume_ok.consumer_tag)

        raise e
      end

      # in case there is another exclusive consumer and we get a channel.close
      # response here. MK.
      raise_if_channel_close!(@last_basic_consume_ok)

      # covers server-generated consumer tags
      add_consumer(queue_name, @last_basic_consume_ok.consumer_tag, no_ack, exclusive, arguments, &block)

      @last_basic_consume_ok
    end
    alias consume basic_consume

    # Registers a consumer for queue as {Bunny::Consumer} instance.
    #
    # @param [Bunny::Consumer] consumer Consumer to register. It should already have queue name, consumer tag
    #                                   and other attributes set.
    #
    # @return [AMQ::Protocol::Basic::ConsumeOk] RabbitMQ response
    # @see http://rubybunny.info/articles/queues.html Queues and Consumers guide
    # @api public
    def basic_consume_with(consumer)
      raise_if_no_longer_open!
      maybe_start_consumer_work_pool!

      # helps avoid race condition between basic.consume-ok and basic.deliver if there are messages
      # in the queue already. MK.
      if consumer.consumer_tag && consumer.consumer_tag.strip != AMQ::Protocol::EMPTY_STRING
        register_consumer(consumer.consumer_tag, consumer)
      end

      @connection.send_frame(AMQ::Protocol::Basic::Consume.encode(@id,
          consumer.queue_name,
          consumer.consumer_tag,
          false,
          consumer.no_ack,
          consumer.exclusive,
          false,
          consumer.arguments))

      begin
        Bunny::Timeout.timeout(wait_on_continuations_timeout, ClientTimeout) do
          @last_basic_consume_ok = wait_on_continuations
        end
      rescue Exception => e
        # if basic.consume-ok never arrives, unregister the proactively
        # registered consumer. MK.
        unregister_consumer(@last_basic_consume_ok.consumer_tag)

        raise e
      end

      # in case there is another exclusive consumer and we get a channel.close
      # response here. MK.
      raise_if_channel_close!(@last_basic_consume_ok)

      # covers server-generated consumer tags
      register_consumer(@last_basic_consume_ok.consumer_tag, consumer)

      raise_if_continuation_resulted_in_a_channel_error!

      @last_basic_consume_ok
    end
    alias consume_with basic_consume_with

    # Removes a consumer. Messages for this consumer will no longer be delivered. If the queue
    # it was on is auto-deleted and this consumer was the last one, the queue will be deleted.
    #
    # @param [String] consumer_tag Consumer tag (unique identifier) to cancel
    #
    # @return [AMQ::Protocol::Basic::CancelOk] RabbitMQ response
    # @see http://rubybunny.info/articles/queues.html Queues and Consumers guide
    # @api public
    def basic_cancel(consumer_tag)
      @connection.send_frame(AMQ::Protocol::Basic::Cancel.encode(@id, consumer_tag, false))

      Bunny::Timeout.timeout(wait_on_continuations_timeout, ClientTimeout) do
        @last_basic_cancel_ok = wait_on_continuations
      end

      # reduces thread usage for channels that don't have any
      # consumers
      @work_pool.shutdown(true) unless self.any_consumers?

      @last_basic_cancel_ok
    end

    # @return [Boolean] true if there are consumers on this channel
    # @api public
    def any_consumers?
      @consumer_mutex.synchronize { @consumers.any? }
    end

    # @endgroup


    # @group Queue operations (queue.*)

    # Declares a queue using queue.declare AMQP 0.9.1 method.
    #
    # @param [String] name Queue name
    # @param [Hash] opts Queue properties
    #
    # @option opts [Boolean] durable (false)     Should information about this queue be persisted to disk so that it
    #                                            can survive broker restarts? Typically set to true for long-lived queues.
    # @option opts [Boolean] auto_delete (false) Should this queue be deleted when the last consumer is cancelled?
    # @option opts [Boolean] exclusive (false) Should only this connection be able to use this queue?
    #                                          If true, the queue will be automatically deleted when this
    #                                          connection is closed
    # @option opts [Boolean] passive (false)   If true, queue will be checked for existence. If it does not
    #                                          exist, {Bunny::NotFound} will be raised.
    #
    # @return [AMQ::Protocol::Queue::DeclareOk] RabbitMQ response
    # @see http://rubybunny.info/articles/queues.html Queues and Consumers guide
    # @api public
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
      @last_queue_declare_ok = wait_on_continuations

      raise_if_continuation_resulted_in_a_channel_error!

      @last_queue_declare_ok
    end

    # Deletes a queue using queue.delete AMQP 0.9.1 method
    #
    # @param [String] name Queue name
    # @param [Hash] opts Options
    #
    # @option opts [Boolean] if_unused (false) Should this queue be deleted only if it has no consumers?
    # @option opts [Boolean] if_empty (false) Should this queue be deleted only if it has no messages?
    #
    # @return [AMQ::Protocol::Queue::DeleteOk] RabbitMQ response
    # @see http://rubybunny.info/articles/queues.html Queues and Consumers guide
    # @api public
    def queue_delete(name, opts = {})
      raise_if_no_longer_open!

      @connection.send_frame(AMQ::Protocol::Queue::Delete.encode(@id,
          name,
          opts[:if_unused],
          opts[:if_empty],
          false))
      Bunny::Timeout.timeout(wait_on_continuations_timeout, ClientTimeout) do
        @last_queue_delete_ok = wait_on_continuations
      end
      raise_if_continuation_resulted_in_a_channel_error!

      @last_queue_delete_ok
    end

    # Purges a queue (removes all messages from it) using queue.purge AMQP 0.9.1 method.
    #
    # @param [String] name Queue name
    #
    # @return [AMQ::Protocol::Queue::PurgeOk] RabbitMQ response
    # @see http://rubybunny.info/articles/queues.html Queues and Consumers guide
    # @api public
    def queue_purge(name, opts = {})
      raise_if_no_longer_open!

      @connection.send_frame(AMQ::Protocol::Queue::Purge.encode(@id, name, false))

      Bunny::Timeout.timeout(wait_on_continuations_timeout, ClientTimeout) do
        @last_queue_purge_ok = wait_on_continuations
      end
      raise_if_continuation_resulted_in_a_channel_error!

      @last_queue_purge_ok
    end

    # Binds a queue to an exchange using queue.bind AMQP 0.9.1 method
    #
    # @param [String] name Queue name
    # @param [String] exchange Exchange name
    # @param [Hash] opts Options
    #
    # @option opts [String] routing_key (nil) Routing key used for binding
    # @option opts [Hash] arguments ({}) Optional arguments
    #
    # @return [AMQ::Protocol::Queue::BindOk] RabbitMQ response
    # @see http://rubybunny.info/articles/queues.html Queues and Consumers guide
    # @see http://rubybunny.info/articles/bindings.html Bindings guide
    # @api public
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
          (opts[:routing_key] || opts[:key]),
          false,
          opts[:arguments]))
      Bunny::Timeout.timeout(wait_on_continuations_timeout, ClientTimeout) do
        @last_queue_bind_ok = wait_on_continuations
      end

      raise_if_continuation_resulted_in_a_channel_error!
      @last_queue_bind_ok
    end

    # Unbinds a queue from an exchange using queue.unbind AMQP 0.9.1 method
    #
    # @param [String] name Queue name
    # @param [String] exchange Exchange name
    # @param [Hash] opts Options
    #
    # @option opts [String] routing_key (nil) Routing key used for binding
    # @option opts [Hash] arguments ({}) Optional arguments
    #
    # @return [AMQ::Protocol::Queue::UnbindOk] RabbitMQ response
    # @see http://rubybunny.info/articles/queues.html Queues and Consumers guide
    # @see http://rubybunny.info/articles/bindings.html Bindings guide
    # @api public
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
      Bunny::Timeout.timeout(wait_on_continuations_timeout, ClientTimeout) do
        @last_queue_unbind_ok = wait_on_continuations
      end

      raise_if_continuation_resulted_in_a_channel_error!
      @last_queue_unbind_ok
    end

    # @endgroup


    # @group Exchange operations (exchange.*)

    # Declares a echange using echange.declare AMQP 0.9.1 method.
    #
    # @param [String] name Exchange name
    # @param [String,Symbol] type Exchange type, e.g. :fanout or :topic
    # @param [Hash] opts Exchange properties
    #
    # @option opts [Boolean] durable (false)     Should information about this echange be persisted to disk so that it
    #                                            can survive broker restarts? Typically set to true for long-lived exchanges.
    # @option opts [Boolean] auto_delete (false) Should this echange be deleted when it is no longer used?
    # @option opts [Boolean] passive (false)   If true, exchange will be checked for existence. If it does not
    #                                          exist, {Bunny::NotFound} will be raised.
    #
    # @return [AMQ::Protocol::Exchange::DeclareOk] RabbitMQ response
    # @see http://rubybunny.info/articles/echanges.html Exchanges and Publishing guide
    # @api public
    def exchange_declare(name, type, opts = {})
      raise_if_no_longer_open!

      @connection.send_frame(AMQ::Protocol::Exchange::Declare.encode(@id,
          name,
          type.to_s,
          opts.fetch(:passive, false),
          opts.fetch(:durable, false),
          opts.fetch(:auto_delete, false),
          opts.fetch(:internal, false),
          false, # nowait
          opts[:arguments]))
      Bunny::Timeout.timeout(wait_on_continuations_timeout, ClientTimeout) do
        @last_exchange_declare_ok = wait_on_continuations
      end

      raise_if_continuation_resulted_in_a_channel_error!
      @last_exchange_declare_ok
    end

    # Deletes a exchange using exchange.delete AMQP 0.9.1 method
    #
    # @param [String] name Exchange name
    # @param [Hash] opts Options
    #
    # @option opts [Boolean] if_unused (false) Should this exchange be deleted only if it is no longer used
    #
    # @return [AMQ::Protocol::Exchange::DeleteOk] RabbitMQ response
    # @see http://rubybunny.info/articles/exchanges.html Exchanges and Publishing guide
    # @api public
    def exchange_delete(name, opts = {})
      raise_if_no_longer_open!

      @connection.send_frame(AMQ::Protocol::Exchange::Delete.encode(@id,
          name,
          opts[:if_unused],
          false))
      Bunny::Timeout.timeout(wait_on_continuations_timeout, ClientTimeout) do
        @last_exchange_delete_ok = wait_on_continuations
      end

      raise_if_continuation_resulted_in_a_channel_error!
      @last_exchange_delete_ok
    end

    # Binds an exchange to another exchange using exchange.bind AMQP 0.9.1 extension
    # that RabbitMQ provides.
    #
    # @param [String] source Source exchange name
    # @param [String] destination Destination exchange name
    # @param [Hash] opts Options
    #
    # @option opts [String] routing_key (nil) Routing key used for binding
    # @option opts [Hash] arguments ({}) Optional arguments
    #
    # @return [AMQ::Protocol::Exchange::BindOk] RabbitMQ response
    # @see http://rubybunny.info/articles/exchanges.html Exchanges and Publishing guide
    # @see http://rubybunny.info/articles/bindings.html Bindings guide
    # @see http://rubybunny.info/articles/extensions.html RabbitMQ Extensions guide
    # @api public
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
      Bunny::Timeout.timeout(wait_on_continuations_timeout, ClientTimeout) do
        @last_exchange_bind_ok = wait_on_continuations
      end

      raise_if_continuation_resulted_in_a_channel_error!
      @last_exchange_bind_ok
    end

    # Unbinds an exchange from another exchange using exchange.unbind AMQP 0.9.1 extension
    # that RabbitMQ provides.
    #
    # @param [String] source Source exchange name
    # @param [String] destination Destination exchange name
    # @param [Hash] opts Options
    #
    # @option opts [String] routing_key (nil) Routing key used for binding
    # @option opts [Hash] arguments ({}) Optional arguments
    #
    # @return [AMQ::Protocol::Exchange::UnbindOk] RabbitMQ response
    # @see http://rubybunny.info/articles/exchanges.html Exchanges and Publishing guide
    # @see http://rubybunny.info/articles/bindings.html Bindings guide
    # @see http://rubybunny.info/articles/extensions.html RabbitMQ Extensions guide
    # @api public
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
      Bunny::Timeout.timeout(wait_on_continuations_timeout, ClientTimeout) do
        @last_exchange_unbind_ok = wait_on_continuations
      end

      raise_if_continuation_resulted_in_a_channel_error!
      @last_exchange_unbind_ok
    end

    # @endgroup



    # @group Flow control (channel.*)

    # Enables or disables message flow for the channel. When message flow is disabled,
    # no new messages will be delivered to consumers on this channel. This is typically
    # used by consumers that cannot keep up with the influx of messages.
    #
    # @note Recent (e.g. 2.8.x., 3.x) RabbitMQ will employ TCP/IP-level back pressure on publishers if it detects
    #       that consumers do not keep up with them.
    #
    # @return [AMQ::Protocol::Channel::FlowOk] RabbitMQ response
    # @see http://rubybunny.info/articles/queues.html Queues and Consumers guide
    # @api public
    def channel_flow(active)
      raise_if_no_longer_open!

      @connection.send_frame(AMQ::Protocol::Channel::Flow.encode(@id, active))
      Bunny::Timeout.timeout(wait_on_continuations_timeout, ClientTimeout) do
        @last_channel_flow_ok = wait_on_continuations
      end
      raise_if_continuation_resulted_in_a_channel_error!

      @last_channel_flow_ok
    end

    # @endgroup



    # @group Transactions (tx.*)

    # Puts the channel into transaction mode (starts a transaction)
    # @return [AMQ::Protocol::Tx::SelectOk] RabbitMQ response
    # @api public
    def tx_select
      raise_if_no_longer_open!

      @connection.send_frame(AMQ::Protocol::Tx::Select.encode(@id))
      Bunny::Timeout.timeout(wait_on_continuations_timeout, ClientTimeout) do
        @last_tx_select_ok = wait_on_continuations
      end
      raise_if_continuation_resulted_in_a_channel_error!
      @tx_mode = true

      @last_tx_select_ok
    end

    # Commits current transaction
    # @return [AMQ::Protocol::Tx::CommitOk] RabbitMQ response
    # @api public
    def tx_commit
      raise_if_no_longer_open!

      @connection.send_frame(AMQ::Protocol::Tx::Commit.encode(@id))
      Bunny::Timeout.timeout(wait_on_continuations_timeout, ClientTimeout) do
        @last_tx_commit_ok = wait_on_continuations
      end
      raise_if_continuation_resulted_in_a_channel_error!

      @last_tx_commit_ok
    end

    # Rolls back current transaction
    # @return [AMQ::Protocol::Tx::RollbackOk] RabbitMQ response
    # @api public
    def tx_rollback
      raise_if_no_longer_open!

      @connection.send_frame(AMQ::Protocol::Tx::Rollback.encode(@id))
      Bunny::Timeout.timeout(wait_on_continuations_timeout, ClientTimeout) do
        @last_tx_rollback_ok = wait_on_continuations
      end
      raise_if_continuation_resulted_in_a_channel_error!

      @last_tx_rollback_ok
    end

    # @return [Boolean] true if this channel has transactions enabled
    def using_tx?
      !!@tx_mode
    end

    # @endgroup



    # @group Publisher Confirms (confirm.*)

    # @return [Boolean] true if this channel has Publisher Confirms enabled, false otherwise
    # @api public
    def using_publisher_confirmations?
      @next_publish_seq_no > 0
    end
    alias using_publisher_confirms? using_publisher_confirmations?

    # Enables publisher confirms for the channel.
    # @return [AMQ::Protocol::Confirm::SelectOk] RabbitMQ response
    # @see #wait_for_confirms
    # @see #unconfirmed_set
    # @see #nacked_set
    # @see http://rubybunny.info/articles/extensions.html RabbitMQ Extensions guide
    # @api public
    def confirm_select(callback = nil)
      raise_if_no_longer_open!

      if @next_publish_seq_no == 0
        @confirms_continuations = new_continuation
        @unconfirmed_set        = Set.new
        @nacked_set             = Set.new
        @next_publish_seq_no    = 1
        @only_acks_received = true
      end

      @confirms_callback = callback

      @connection.send_frame(AMQ::Protocol::Confirm::Select.encode(@id, false))
      Bunny::Timeout.timeout(wait_on_continuations_timeout, ClientTimeout) do
        @last_confirm_select_ok = wait_on_continuations
      end
      raise_if_continuation_resulted_in_a_channel_error!
      @last_confirm_select_ok
    end

    # Blocks calling thread until confirms are received for all
    # currently unacknowledged published messages. Returns immediately
    # if there are no outstanding confirms.
    #
    # @return [Boolean] true if all messages were acknowledged positively since the last time this method was called, false otherwise
    # @see #confirm_select
    # @see #unconfirmed_set
    # @see #nacked_set
    # @see http://rubybunny.info/articles/extensions.html RabbitMQ Extensions guide
    # @api public
    def wait_for_confirms
      wait_on_confirms_continuations
      read_and_reset_only_acks_received
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
    # Error Handilng
    #

    # Defines a handler for errors that are not responses to a particular
    # operations (e.g. basic.ack, basic.reject, basic.nack).
    #
    # @api public
    def on_error(&block)
      @on_error = block
    end

    # Defines a handler for uncaught exceptions in consumers
    # (e.g. delivered message handlers).
    #
    # @api public
    def on_uncaught_exception(&block)
      @uncaught_exception_handler = block
    end

    #
    # Recovery
    #

    # @group Network Failure Recovery

    # Recovers basic.qos setting, exchanges, queues and consumers. Used by the Automatic Network Failure
    # Recovery feature.
    #
    # @api plugin
    def recover_from_network_failure
      @logger.debug { "Recovering channel #{@id} after network failure" }
      release_all_continuations

      recover_prefetch_setting
      recover_confirm_mode
      recover_tx_mode
      recover_exchanges
      # this includes recovering bindings
      recover_queues
      recover_consumers
      increment_recoveries_counter
    end

    # Recovers basic.qos setting. Used by the Automatic Network Failure
    # Recovery feature.
    #
    # @api plugin
    def recover_prefetch_setting
      basic_qos(@prefetch_count, @prefetch_global) if @prefetch_count
    end

    # Recovers publisher confirms mode. Used by the Automatic Network Failure
    # Recovery feature.
    #
    # @api plugin
    def recover_confirm_mode
      if using_publisher_confirmations?
        @unconfirmed_set.clear
        @delivery_tag_offset = @next_publish_seq_no - 1
        confirm_select(@confirms_callback)
      end
    end

    # Recovers transaction mode. Used by the Automatic Network Failure
    # Recovery feature.
    #
    # @api plugin
    def recover_tx_mode
      tx_select if @tx_mode
    end

    # Recovers exchanges. Used by the Automatic Network Failure
    # Recovery feature.
    #
    # @api plugin
    def recover_exchanges
      @exchange_mutex.synchronize { @exchanges.values }.each do |x|
        x.recover_from_network_failure
      end
    end

    # Recovers queues and bindings. Used by the Automatic Network Failure
    # Recovery feature.
    #
    # @api plugin
    def recover_queues
      @queue_mutex.synchronize { @queues.values }.each do |q|
        @logger.debug { "Recovering queue #{q.name}" }
        q.recover_from_network_failure
      end
    end

    # Recovers consumers. Used by the Automatic Network Failure
    # Recovery feature.
    #
    # @api plugin
    def recover_consumers
      unless @consumers.empty?
        @work_pool = ConsumerWorkPool.new(@work_pool.size, @work_pool.abort_on_exception)
        @work_pool.start
      end

      @consumer_mutex.synchronize { @consumers.values }.each do |c|
        c.recover_from_network_failure
      end
    end

    # @private
    def increment_recoveries_counter
      @recoveries_counter.increment
    end

    # @api public
    def recover_cancelled_consumers!
      @recover_cancelled_consumers = true
    end

    # @api public
    def recovers_cancelled_consumers?
      !!@recover_cancelled_consumers
    end

    # @endgroup


    # @return [String] Brief human-readable representation of the channel
    def to_s
      "#<#{self.class.name}:#{object_id} @id=#{self.number} @connection=#{@connection.to_s}>"
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
    def unregister_consumer(consumer_tag)
      @consumer_mutex.synchronize do
        @consumers.delete(consumer_tag)
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
      @logger.debug { "Channel#handle_frame on channel #{@id}: #{method.inspect}" }
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
          @work_pool.submit do
            begin
              if recovers_cancelled_consumers?
                consumer.handle_cancellation(method)
                @logger.info "Automatically recovering cancelled consumer #{consumer.consumer_tag} on queue #{consumer.queue_name}"

                consume_with(consumer)
              else
                @consumers.delete(method.consumer_tag)
                consumer.handle_cancellation(method)
              end
            rescue Exception => e
              @logger.error "Got exception when notifying consumer #{method.consumer_tag} about cancellation!"
              @uncaught_exception_handler.call(e, consumer) if @uncaught_exception_handler
            end
          end
        else
          @logger.warn "No consumer for tag #{method.consumer_tag} on channel #{@id}!"
        end
      when AMQ::Protocol::Basic::CancelOk then
        @continuations.push(method)
        unregister_consumer(method.consumer_tag)
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
        closed!
        @connection.send_frame(AMQ::Protocol::Channel::CloseOk.encode(@id))

        # basic.ack, basic.reject, basic.nack. MK.
        if channel_level_exception_after_operation_that_has_no_response?(method)
          @on_error.call(self, method) if @on_error
        else
          @last_channel_error = instantiate_channel_level_exception(method)
          @continuations.push(method)
        end

      when AMQ::Protocol::Channel::CloseOk then
        @continuations.push(method)
      else
        raise "Do not know how to handle #{method.inspect} in Bunny::Channel#handle_method"
      end
    end

    # @private
    def channel_level_exception_after_operation_that_has_no_response?(method)
      method.reply_code == 406 && method.reply_text =~ /unknown delivery tag/
    end

    # @private
    def handle_basic_get_ok(basic_get_ok, properties, content)
      basic_get_ok.delivery_tag = VersionedDeliveryTag.new(basic_get_ok.delivery_tag, @recoveries_counter.get)
      @basic_get_continuations.push([basic_get_ok, properties, content])
    end

    # @private
    def handle_basic_get_empty(basic_get_empty)
      @basic_get_continuations.push([nil, nil, nil])
    end

    # @private
    def handle_frameset(basic_deliver, properties, content)
      consumer = @consumers[basic_deliver.consumer_tag]
      if consumer
        @work_pool.submit do
          begin
            consumer.call(DeliveryInfo.new(basic_deliver, consumer, self), MessageProperties.new(properties), content)
          rescue StandardError => e
            @uncaught_exception_handler.call(e, consumer) if @uncaught_exception_handler
          end
        end
      else
        @logger.warn "No consumer for tag #{basic_deliver.consumer_tag} on channel #{@id}!"
      end
    end

    # @private
    def handle_basic_return(basic_return, properties, content)
      x = find_exchange(basic_return.exchange)

      if x
        x.handle_return(ReturnInfo.new(basic_return), MessageProperties.new(properties), content)
      else
        @logger.warn "Exchange #{basic_return.exchange} is not in channel #{@id}'s cache! Dropping returned message!"
      end
    end

    # @private
    def handle_ack_or_nack(delivery_tag_before_offset, multiple, nack)
      delivery_tag          = delivery_tag_before_offset + @delivery_tag_offset
      confirmed_range_start = multiple ? @delivery_tag_offset + 1 : delivery_tag
      confirmed_range_end   = delivery_tag
      confirmed_range       = (confirmed_range_start..confirmed_range_end)

      @unconfirmed_set_mutex.synchronize do
        if nack
          @nacked_set.merge(@unconfirmed_set & confirmed_range)
        end

        @unconfirmed_set.subtract(confirmed_range)

        @only_acks_received = (@only_acks_received && !nack)

        @confirms_continuations.push(true) if @unconfirmed_set.empty?

        if @confirms_callback
          confirmed_range.each { |tag| @confirms_callback.call(tag, false, nack) }
        end
      end
    end

    # @private
    def wait_on_continuations
      if @connection.threaded
        t = Thread.current
        @threads_waiting_on_continuations << t

        begin
          @continuations.poll(@connection.continuation_timeout)
        ensure
          @threads_waiting_on_continuations.delete(t)
        end
      else
        connection.reader_loop.run_once until @continuations.length > 0

        @continuations.pop
      end
    end

    # @private
    def wait_on_basic_get_continuations
      if @connection.threaded
        t = Thread.current
        @threads_waiting_on_basic_get_continuations << t

        begin
          @basic_get_continuations.poll(@connection.continuation_timeout)
        ensure
          @threads_waiting_on_basic_get_continuations.delete(t)
        end
      else
        connection.reader_loop.run_once until @basic_get_continuations.length > 0

        @basic_get_continuations.pop
      end
    end

    # @private
    def wait_on_confirms_continuations
      raise_if_no_longer_open!

      if @connection.threaded
        t = Thread.current
        @threads_waiting_on_confirms_continuations << t

        begin
          while @unconfirmed_set_mutex.synchronize { !@unconfirmed_set.empty? }
            @confirms_continuations.poll(@connection.continuation_timeout)
          end
        ensure
          @threads_waiting_on_confirms_continuations.delete(t)
        end
      else
        unless @unconfirmed_set.empty?
          connection.reader_loop.run_once until @confirms_continuations.length > 0
          @confirms_continuations.pop
        end
      end
    end

    # @private
    def read_and_reset_only_acks_received
      @unconfirmed_set_mutex.synchronize do
        result = @only_acks_received
        @only_acks_received = true
        result
      end
    end


    # Releases all continuations. Used by automatic network recovery.
    # @private
    def release_all_continuations
      @threads_waiting_on_confirms_continuations.each do |t|
        t.run
      end
      @threads_waiting_on_continuations.each do |t|
        t.run
      end
      @threads_waiting_on_basic_get_continuations.each do |t|
        t.run
      end

      self.reset_continuations
    end

    # Starts consumer work pool. Lazily called by #basic_consume to avoid creating new threads
    # that won't do any real work for channels that do not register consumers (e.g. only used for
    # publishing). MK.
    # @private
    def maybe_start_consumer_work_pool!
      if @work_pool && !@work_pool.running?
        @work_pool.start
      end
    end

    # @private
    def maybe_pause_consumer_work_pool!
      @work_pool.pause if @work_pool && @work_pool.running?
    end

    # @private
    def maybe_kill_consumer_work_pool!
      if @work_pool && @work_pool.running?
        @work_pool.kill
      end
    end

    # @private
    def read_next_frame(options = {})
      @connection.read_next_frame(options = {})
    end

    # @private
    def deregister_queue(queue)
      @queue_mutex.synchronize { @queues.delete(queue.name) }
    end

    # @private
    def deregister_queue_named(name)
      @queue_mutex.synchronize { @queues.delete(name) }
    end

    # @private
    def register_queue(queue)
      @queue_mutex.synchronize { @queues[queue.name] = queue }
    end

    # @private
    def find_queue(name)
      @queue_mutex.synchronize { @queues[name] }
    end

    # @private
    def deregister_exchange(exchange)
      @exchange_mutex.synchronize { @exchanges.delete(exchange.name) }
    end

    # @private
    def register_exchange(exchange)
      @exchange_mutex.synchronize { @exchanges[exchange.name] = exchange }
    end

    # @private
    def find_exchange(name)
      @exchange_mutex.synchronize { @exchanges[name] }
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

    # @private
    def raise_if_channel_close!(method)
      if method && method.is_a?(AMQ::Protocol::Channel::Close)
        # basic.ack, basic.reject, basic.nack. MK.
        if channel_level_exception_after_operation_that_has_no_response?(method)
          @on_error.call(self, method) if @on_error
        else
          @last_channel_error = instantiate_channel_level_exception(method)
          raise @last_channel_error
        end
      end
    end

    # @private
    def reset_continuations
      @continuations           = new_continuation
      @confirms_continuations  = new_continuation
      @basic_get_continuations = new_continuation
    end


    if defined?(JRUBY_VERSION)
      # @private
      def new_continuation
        Concurrent::LinkedContinuationQueue.new
      end
    else
      # @private
      def new_continuation
        Concurrent::ContinuationQueue.new
      end
    end # if defined?

    # @private
    def guarding_against_stale_delivery_tags(tag, &block)
      case tag
        # if a fixnum was passed, execute unconditionally. MK.
      when Integer then
        block.call
        # versioned delivery tags should be checked to avoid
        # sending out stale (invalid) tags after channel was reopened
        # during network failure recovery. MK.
      when VersionedDeliveryTag then
        if !tag.stale?(@recoveries_counter.get)
          block.call
        end
      end
    end
  end # Channel
end # Bunny
