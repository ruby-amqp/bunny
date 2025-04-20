# -*- coding: utf-8 -*-
# frozen_string_literal: true

require "set"

module Bunny
  class TopologyRegistry
    def initialize(opts = {})
      @mutex_impl = Monitor

      self.reset!
    end

    def reset!
      @queues = {}
      @exchanges = {}
      @queue_bindings = Set.new
      @exchange_bindings = Set.new
      @consumers = {}

      @queue_mutex = @mutex_impl.new
      @exchange_mutex = @mutex_impl.new
      @binding_mutex = @mutex_impl.new
      @consumer_mutex = @mutex_impl.new
    end

    #
    # Queues
    #

    # @return [Hash<String, Bunny::RecordedQueue>]
    attr_reader :queues

    # @param [Bunny::Queue] queue
    def record_queue(queue)
      @queue_mutex.synchronize { @queues[queue.name] = RecordedQueue::from(queue) }
    end

    # @param [Bunny::Channel] ch
    # @param [String] name
    # @param [Boolean] server_named
    # @param [Boolean] durable
    # @param [Boolean] auto_delete
    # @param [Boolean] exclusive
    # @param [Hash] arguments
    def record_queue_with(ch, name, server_named, durable, auto_delete, exclusive, arguments)
      queue = RecordedQueue.new(ch, name)
        .with_server_named(server_named)
        .with_durable(durable)
        .with_auto_delete(auto_delete)
        .with_exclusive(exclusive)
        .with_arguments(arguments)

        @queue_mutex.synchronize { @queues[queue.name] = queue }
    end

    # @param [Bunny::Queue, Bunny::RecordedQueue] queue
    def delete_recorded_queue(queue)
      self.delete_recorded_queue_named(queue.name)
    end

    # @param [String] name
    def delete_recorded_queue_named(name)
      @queue_mutex.synchronize do
        @queues.delete(name)

        bs = self.remove_recorded_bindings_with_destination(name)
        bs.each do |b|
          self.maybe_delete_recorded_auto_delete_exchange(b.source)
        end
      end
    end

    #
    # Consumers
    #

    # @return [Hash<String, Bunny::RecordedConsumer>]
    attr_reader :consumers

    # @param [Bunny::Channel] ch
    # @param [String] consumer_tag
    # @param [String] queue_name
    # @param [#call] callable
    # @param [Boolean] manual_ack
    # @param [Boolean] exclusive
    # @param [Hash] arguments
    def record_consumer_with(ch, consumer_tag, queue_name, callable, manual_ack, exclusive, arguments)
      @consumer_mutex.synchronize do
        cons = RecordedConsumer.new(ch, queue_name)
          .with_consumer_tag(consumer_tag)
          .with_callable(callable)
          .with_manual_ack(manual_ack)
          .with_exclusive(exclusive)
          .with_arguments(arguments)

        @consumers[consumer_tag] = cons
      end
    end

    # @param [String] consumer_tag
    def delete_recorded_consumer(consumer_tag)
      @consumer_mutex.synchronize do
        if (val = @consumers.delete(consumer_tag))
          self.maybe_delete_recorded_auto_delete_queue(val.queue_name)
        end
      end
    end

    #
    # Exchanges
    #

    attr_reader :exchanges

    # @param [Bunny::Exchange] exchange
    def record_exchange(exchange)
      @exchange_mutex.synchronize { @exchanges[exchange.name] = RecordedExchange::from(exchange) }
    end

    # @param [Bunny::Channel] ch
    # @param [String] name
    # @param [String] type
    # @param [Boolean] durable
    # @param [Boolean] auto_delete
    # @param [Hash] arguments
    def record_exchange_with(ch, name, type, durable, auto_delete, arguments)
      exchange = RecordedExchange.new(ch, name)
        .with_type(type)
        .with_durable(durable)
        .with_auto_delete(auto_delete)
        .with_arguments(arguments)

        @exchange_mutex.synchronize { @exchanges[exchange.name] = exchange }
    end

    # @param [Bunny::Exchange, Bunny::RecordedExchange] exchange
    def delete_recorded_exchange(exchange)
      self.delete_recorded_exchange_named(exchange.name)
    end

    # @param [String] name
    def delete_recorded_exchange_named(name)
      @exchange_mutex.synchronize do
        @exchanges.delete(name)
        bs1 = self.remove_recorded_bindings_with_source(name)
        bs2 = self.remove_recorded_bindings_with_destination(name)

        bs1.each do |b|
          self.maybe_delete_recorded_auto_delete_exchange(b.source)
        end

        bs2.each do |b|
          self.maybe_delete_recorded_auto_delete_exchange(b.source)
        end
      end
    end

    #
    # Bindings
    #

    # @return Set<Bunny::RecordedQueueBinding>
    attr_reader :queue_bindings
    # @return Set<Bunny::RecordedExchangeBinding>
    attr_reader :exchange_bindings

    # @param [Bunny::Channel] ch
    # @param [String] exchange_name
    # @param [String] queue_name
    # @param [#call] callable
    # @param [String] routing_key
    # @param [Hash] arguments
    def record_queue_binding_with(ch, exchange_name, queue_name, routing_key, arguments)
      b = RecordedQueueBinding.new(ch)
        .with_source(exchange_name)
        .with_destination(queue_name)
        .with_routing_key(routing_key)
        .with_arguments(arguments)

      @binding_mutex.synchronize { @queue_bindings.add(b) }
    end

    # @param [Bunny::Channel] ch
    # @param [String] exchange_name
    # @param [String] queue_name
    # @param [#call] callable
    # @param [String] routing_key
    # @param [Hash] arguments
    def delete_recorded_queue_binding(ch, exchange_name, queue_name, routing_key, arguments)
      b = RecordedQueueBinding.new(ch)
      .with_source(exchange_name)
      .with_destination(queue_name)
      .with_routing_key(routing_key)
      .with_arguments(arguments)

      @binding_mutex.synchronize { @queue_bindings.delete(b) }
    end

    # @param [Bunny::Channel] ch
    # @param [String] source_name
    # @param [String] destination_name
    # @param [#call] callable
    # @param [String] routing_key
    # @param [Hash] arguments
    def record_exchange_binding_with(ch, source_name, destination_name, routing_key, arguments)
      b = RecordedExchangeBinding.new(ch)
        .with_source(source_name)
        .with_destination(destination_name)
        .with_routing_key(routing_key)
        .with_arguments(arguments)

      @binding_mutex.synchronize { @exchange_bindings.add(b) }
    end

    # @param [Bunny::Channel] ch
    # @param [String] source_name
    # @param [String] destination_name
    # @param [#call] callable
    # @param [String] routing_key
    # @param [Hash] arguments
    def delete_recorded_exchange_binding(ch, source_name, destination_name, routing_key, arguments)
      b = RecordedExchangeBinding.new(ch)
        .with_source(source_name)
        .with_destination(destination_name)
        .with_routing_key(routing_key)
        .with_arguments(arguments)

      @binding_mutex.synchronize do
        if @exchange_bindings.delete?(b)
          self.maybe_delete_recorded_auto_delete_exchange(source_name)
        end
      end
    end

    #
    # Implementation
    #

    # @param name [String] Auto-delete queue name
    def maybe_delete_recorded_auto_delete_queue(name)
      @queue_mutex.synchronize do
        unless self.has_more_consumers_on_queue?(@consumers.values, name)
          if (q = @queues[name])
            self.delete_recorded_queue(q)
          end
        end
      end
    end

    # @param name [String] Auto-delete exchange name
    def maybe_delete_recorded_auto_delete_exchange(name)
      @exchange_mutex.synchronize do
        unless self.has_more_destinations_bound_to_exchange?(@queue_bindings.dup, @exchange_bindings.dup, name)
          self.delete_recorded_exchange_named(name)
        end
      end
    end

    # @param name [String]
    # @return Set<Bunny::RecordedBinding>
    def remove_recorded_bindings_with_source(name)
      @binding_mutex.synchronize do
        matching_qbs = self.queue_bindings.filter { |b| b.source == name }
        matching_xbs = self.exchange_bindings.filter { |b| b.source == name }

        matches = matching_qbs + matching_xbs
        matches.each do |b|
          @queue_bindings.delete(b)
          @exchange_bindings.delete(b)
        end

        matches
      end
    end

    # @param name [String]
    # @return Set<Bunny::RecordedBinding>
    def remove_recorded_bindings_with_destination(name)
      @binding_mutex.synchronize do
        matching_qbs = self.queue_bindings.filter { |b| b.destination == name }
        matching_xbs = self.exchange_bindings.filter { |b| b.destination == name }

        matches = matching_qbs + matching_xbs
        matches.each do |b|
          @queue_bindings.delete(b)
          @exchange_bindings.delete(b)
        end

        matches
      end
    end

    # @param consumers [Array<Bunny::RecordedConsumer]
    # @param name [String]
    def has_more_consumers_on_queue?(consumers, name)
      return false if consumers.empty?

      consumers.any? { |val| val.queue_name == name }
    end

    # @param queue_bindings [Set<Bunny::RecordedBinding>]
    # @param exchange_bindings [Set<Bunny::RecordedBinding>]
    # @param name [String] Auto-delete exchange name
    def has_more_destinations_bound_to_exchange?(queue_bindings, exchange_bindings, name)
      return false if queue_bindings.empty? && exchange_bindings.empty?

      condition_one = queue_bindings.any? { |val| val.source == name }
      condition_two = exchange_bindings.any? { |val| val.source == name }

      condition_one || condition_two
    end
  end

  #
  # Recordable, Recoverable Entities
  #

  class RecordedEntity
    # @return [Bunny::Channel]
    attr_reader :channel

    # @param ch [Bunny::Channel]
    def initialize(ch)
      @channel = ch
    end
  end

  class RecordedNamedEntity < RecordedEntity
    # @return [String]
    attr_reader :name

    # @param ch [Bunny::Channel]
    # @param name [String]
    def initialize(ch, name)
      @name = name

      super(ch)
    end
  end

  # Represents an exchange declaration intent that can be repeated.
  class RecordedExchange < RecordedNamedEntity
    attr_reader :type, :durable, :auto_delete, :arguments

    def initialize(ch, name)
      super(ch, name)

      @type = nil
      @durable = true
      @auto_delete = false
      @arguments = nil
    end

    # @param value [Boolean]
    def with_durable(value)
      @durable = value
      self
    end

    # @param value [Boolean]
    def with_auto_delete(value)
      @auto_delete = value
      self
    end

    # @param value [Symbol]
    def with_type(value)
      @type = value
      self
    end

    # @param value [Hash]
    def with_arguments(value)
      @arguments = value
      self
    end

    def hash
      [self.class, self.channel, self.name, @type, @durable, @auto_delete, @arguments].hash
    end

    def eql?(other)
      self == other
    end

    def ==(other)
      other.class == self.class &&
        other.name == self.name &&
        other.channel == self.channel &&
        other.durable == self.durable &&
        other.auto_delete == self.auto_delete &&
        other.type == self.type &&
        other.arguments == self.arguments
    end

    # @param [Bunny::Exchange] x
    def self.from(x)
      new(x.channel, x.name)
        .with_type(x.type)
        .with_durable(x.durable?)
        .with_auto_delete(x.auto_delete?)
        .with_arguments(x.arguments)
    end
  end

  # Represents an exchange declaration intent that can be repeated.
  #
  # Server-named queues will acquire a new server-generated name.
  class RecordedQueue < RecordedNamedEntity
    EMPTY_STRING = "".freeze

    attr_reader :durable, :auto_delete, :exclusive, :arguments

    def initialize(ch, name)
      super ch, name

      @durable = true
      @auto_delete = false
      @exclusive = false
      @server_named = false
      @arguments = nil
    end

    # @param value [Boolean]
    def with_durable(value)
      @durable = value
      self
    end

    # @param value [Boolean]
    def with_auto_delete(value)
      @auto_delete = value
      self
    end

    def auto_delete?
      @auto_delete
    end

    # @param value [Boolean]
    def with_exclusive(value)
      @exclusive = value
      self
    end

    def exclusive?
      @exclusive
    end

    # @param value [Boolean]
    def with_server_named(value)
      @server_named = value
      self
    end

    def server_named?
      !!@server_named
    end

    # @param value [Hash]
    def with_arguments(value)
      @arguments = value
      self
    end

    # @return [String]
    def name_to_use_for_recovery
      if server_named?
        EMPTY_STRING
      else
        self.name
      end
    end

    def eql?(other)
      self == other
    end

    def ==(other)
      other.class == self.class &&
        other.name == self.name &&
        other.channel == self.channel &&
        other.durable == self.durable &&
        other.auto_delete == self.auto_delete &&
        other.exclusive == self.exclusive &&
        other.arguments == self.arguments
    end

    def hash
      [self.class, self.channel, @name, @durable].hash
    end

    # @param [Bunny::Queue] q
    def self.from(q)
      new(q.channel, q.name)
        .with_server_named(q.server_named?)
        .with_durable(q.durable?)
        .with_auto_delete(q.auto_delete?)
        .with_exclusive(q.exclusive?)
        .with_arguments(q.arguments)
    end
  end

  # Represents a consumer (subscription) registration intent that can be repeated.
  class RecordedConsumer < RecordedEntity
    # @return [String]
    attr_reader :queue_name, :consumer_tag
    # @return [#call]
    attr_reader :callable
    # @return [Boolean]
    attr_reader :exclusive, :manual_ack
    # @return [Hash]
    attr_reader :arguments

    def initialize(ch, queue_name)
      super ch

      @queue_name = queue_name
      @consumer_tag = nil
      @callable = nil
      @exclusive = false
      @manual_ack = true
      @arguments = Hash.new
    end

    def with_queue_name(value)
      @queue_name = value
      self
    end

    def with_consumer_tag(value)
      @consumer_tag = value
      self
    end

    def with_callable(value)
      @callable = value
      self
    end

    def with_manual_ack(value)
      @manual_ack = value
      self
    end

    def with_exclusive(value)
      @exclusive = value
      self
    end

    def with_arguments(value)
      @arguments = value
      self
    end

    def eql?(other)
      self == other
    end

    def ==(other)
      other.class == self.class &&
        other.channel == self.channel &&
        other.queue_name == self.queue_name &&
        other.callable == self.callable &&
        other.manual_ack == self.manual_ack &&
        other.exclusive == self.exclusive &&
        other.arguments == self.arguments
    end

    def hash
      [self.class, self.channel, @queue_name, @consumer_tag, @callable, @exclusive, @manual_ack, @arguments].hash
    end
  end

  class RecordedBinding < RecordedEntity
    # @return [String]
    attr_reader :source
    # @return [String]
    attr_reader :destination
    # @return [String]
    attr_reader :routing_key
    # @return [Hash]
    attr_reader :arguments

    def initialize(ch)
      super ch

      @source = nil
      @destination = nil
      @routing_key = nil
      @arguments = Hash.new
    end

    # @param value [String]
    def with_source(value)
      @source = value
      self
    end

    # @param value [String]
    def with_destination(value)
      @destination = value
      self
    end

    # @param value [String]
    def with_routing_key(value)
      @routing_key = value
      self
    end

    # @param value [Hash]
    def with_arguments(value)
      @arguments = value
      self
    end

    def hash
      [self.class, @source, @destination, @routing_key, @arguments].hash
    end

    def eql?(other)
      self == other
    end

    def ==(other)
      other.class == self.class &&
        other.source == self.source &&
        other.destination == self.destination &&
        other.routing_key == self.routing_key &&
        other.arguments == self.arguments
    end

    def recover
      raise NotImplementedError.new
    end
  end

  # Represents a queue binding intent that can be repeated.
  class RecordedQueueBinding < RecordedBinding
    def recover

    end
  end

  # Represents an exchange binding intent that can be repeated.
  class RecordedExchangeBinding < RecordedBinding
    def recover

    end
  end

end
