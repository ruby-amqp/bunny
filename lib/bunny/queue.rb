require "bunny/get_response"

module Bunny
  # Represents AMQP 0.9.1 queue.
  #
  # @see http://rubybunny.info/articles/queues.html Queues and Consumers guide
  # @see http://rubybunny.info/articles/extensions.html RabbitMQ Extensions guide
  class Queue

    #
    # API
    #

    # @return [Bunny::Channel] Channel this queue uses
    attr_reader :channel
    # @return [String] Queue name
    attr_reader :name
    # @return [Hash] Options this queue was created with
    attr_reader :options

    # @param [Bunny::Channel] channel Channel this queue will use.
    # @param [String] name                          Queue name. Pass an empty string to make RabbitMQ generate a unique one.
    # @param [Hash] opts                            Queue properties
    #
    # @option opts [Boolean] :durable (false)      Should this queue be durable?
    # @option opts [Boolean] :auto_delete (false)  Should this queue be automatically deleted when the last consumer disconnects?
    # @option opts [Boolean] :exclusive (false)    Should this queue be exclusive (only can be used by this connection, removed when the connection is closed)?
    # @option opts [Boolean] :arguments ({})       Additional optional arguments (typically used by RabbitMQ extensions and plugins)
    #
    # @see Bunny::Channel#queue
    # @see http://rubybunny.info/articles/queues.html Queues and Consumers guide
    # @see http://rubybunny.info/articles/extensions.html RabbitMQ Extensions guide
    # @api public
    def initialize(channel, name = AMQ::Protocol::EMPTY_STRING, opts = {})
      # old Bunny versions pass a connection here. In that case,
      # we just use default channel from it. MK.
      @channel          = channel
      @name             = name
      @options          = self.class.add_default_options(name, opts)

      @durable          = @options[:durable]
      @exclusive        = @options[:exclusive]
      @server_named     = @name.empty?
      @auto_delete      = @options[:auto_delete]
      @arguments        = @options[:arguments]

      @bindings         = Array.new

      @default_consumer = nil

      declare! unless opts[:no_declare]

      @channel.register_queue(self)
    end

    # @return [Boolean] true if this queue was declared as durable (will survive broker restart).
    # @api public
    # @see http://rubybunny.info/articles/queues.html Queues and Consumers guide
    def durable?
      @durable
    end # durable?

    # @return [Boolean] true if this queue was declared as exclusive (limited to just one consumer)
    # @api public
    # @see http://rubybunny.info/articles/queues.html Queues and Consumers guide
    def exclusive?
      @exclusive
    end # exclusive?

    # @return [Boolean] true if this queue was declared as automatically deleted (deleted as soon as last consumer unbinds).
    # @api public
    # @see http://rubybunny.info/articles/queues.html Queues and Consumers guide
    def auto_delete?
      @auto_delete
    end # auto_delete?

    # @return [Boolean] true if this queue was declared as server named.
    # @api public
    # @see http://rubybunny.info/articles/queues.html Queues and Consumers guide
    def server_named?
      @server_named
    end # server_named?

    # @return [Hash] Additional optional arguments (typically used by RabbitMQ extensions and plugins)
    # @api public
    def arguments
      @arguments
    end

    def to_s
      oid = ("0x%x" % (self.object_id << 1))
      "<#{self.class.name}:#{oid} @name=\"#{name}\" channel=#{@channel.to_s} @durable=#{@durable} @auto_delete=#{@auto_delete} @exclusive=#{@exclusive} @arguments=#{@arguments}>"
    end

    def inspect
      to_s
    end

    # Binds queue to an exchange
    #
    # @param [Bunny::Exchange,String] exchange Exchange to bind to
    # @param [Hash] opts                       Binding properties
    #
    # @option opts [String] :routing_key  Routing key
    # @option opts [Hash] :arguments ({}) Additional optional binding arguments
    #
    # @see http://rubybunny.info/articles/queues.html Queues and Consumers guide
    # @see http://rubybunny.info/articles/bindings.html Bindings guide
    # @api public
    def bind(exchange, opts = {})
      @channel.queue_bind(@name, exchange, opts)

      exchange_name = if exchange.respond_to?(:name)
                        exchange.name
                      else
                        exchange
                      end


      # store bindings for automatic recovery. We need to be very careful to
      # not cause an infinite rebinding loop here when we recover. MK.
      binding = { :exchange => exchange_name, :routing_key => (opts[:routing_key] || opts[:key]), :arguments => opts[:arguments] }
      @bindings.push(binding) unless @bindings.include?(binding)

      self
    end

    # Unbinds queue from an exchange
    #
    # @param [Bunny::Exchange,String] exchange Exchange to unbind from
    # @param [Hash] opts                       Binding properties
    #
    # @option opts [String] :routing_key  Routing key
    # @option opts [Hash] :arguments ({}) Additional optional binding arguments
    #
    # @see http://rubybunny.info/articles/queues.html Queues and Consumers guide
    # @see http://rubybunny.info/articles/bindings.html Bindings guide
    # @api public
    def unbind(exchange, opts = {})
      @channel.queue_unbind(@name, exchange, opts)

      exchange_name = if exchange.respond_to?(:name)
                        exchange.name
                      else
                        exchange
                      end


      @bindings.delete_if { |b| b[:exchange] == exchange_name && b[:routing_key] == (opts[:routing_key] || opts[:key]) && b[:arguments] == opts[:arguments] }

      self
    end

    # Adds a consumer to the queue (subscribes for message deliveries).
    #
    # @param [Hash] opts Options
    #
    # @option opts [Boolean] :ack (false) [DEPRECATED] Use :manual_ack instead
    # @option opts [Boolean] :manual_ack (false) Will this consumer use manual acknowledgements?
    # @option opts [Boolean] :exclusive (false) Should this consumer be exclusive for this queue?
    # @option opts [Boolean] :block (false) Should the call block calling thread?
    # @option opts [#call] :on_cancellation Block to execute when this consumer is cancelled remotely (e.g. via the RabbitMQ Management plugin)
    # @option opts [String] :consumer_tag Unique consumer identifier. It is usually recommended to let Bunny generate it for you.
    # @option opts [Hash] :arguments ({}) Additional (optional) arguments, typically used by RabbitMQ extensions
    #
    # @see http://rubybunny.info/articles/queues.html Queues and Consumers guide
    # @api public
    def subscribe(opts = {
                    :consumer_tag    => @channel.generate_consumer_tag,
                    :manual_ack      => false,
                    :exclusive       => false,
                    :block           => false,
                    :on_cancellation => nil
                  }, &block)

      unless opts[:ack].nil?
        warn "[DEPRECATION] `:ack` is deprecated.  Please use `:manual_ack` instead."
        opts[:manual_ack] = opts[:ack]
      end

      ctag       = opts.fetch(:consumer_tag, @channel.generate_consumer_tag)
      consumer   = Consumer.new(@channel,
                                self,
                                ctag,
                                !opts[:manual_ack],
                                opts[:exclusive],
                                opts[:arguments])

      consumer.on_delivery(&block)
      consumer.on_cancellation(&opts[:on_cancellation]) if opts[:on_cancellation]

      @channel.basic_consume_with(consumer)
      if opts[:block]
        # joins current thread with the consumers pool, will block
        # the current thread for as long as the consumer pool is active
        @channel.work_pool.join
      end

      consumer
    end

    # Adds a consumer object to the queue (subscribes for message deliveries).
    #
    # @param [Bunny::Consumer] consumer a {Bunny::Consumer} subclass that implements consumer interface
    # @param [Hash] opts Options
    #
    # @option opts [Boolean] block (false) Should the call block calling thread?
    #
    # @see http://rubybunny.info/articles/queues.html Queues and Consumers guide
    # @api public
    def subscribe_with(consumer, opts = {:block => false})
      @channel.basic_consume_with(consumer)

      @channel.work_pool.join if opts[:block]
      consumer
    end

    # @param [Hash] opts Options
    #
    # @option opts [Boolean] :ack (false) [DEPRECATED] Use :manual_ack instead
    # @option opts [Boolean] :manual_ack (false) Will the message be acknowledged manually?
    #
    # @return [Array] Triple of delivery info, message properties and message content.
    #                 If the queue is empty, all three will be nils.
    # @see http://rubybunny.info/articles/queues.html Queues and Consumers guide
    # @see Bunny::Queue#subscribe
    # @api public
    #
    # @example
    #   conn = Bunny.new
    #   conn.start
    #
    #   ch   = conn.create_channel
    #   q = ch.queue("test1")
    #   x = ch.default_exchange
    #   x.publish("Hello, everybody!", :routing_key => 'test1')
    #
    #   delivery_info, properties, payload = q.pop
    #
    #   puts "This is the message: " + payload + "\n\n"
    #   conn.close
    def pop(opts = {:manual_ack => false}, &block)
      unless opts[:ack].nil?
        warn "[DEPRECATION] `:ack` is deprecated.  Please use `:manual_ack` instead."
        opts[:manual_ack] = opts[:ack]
      end

      get_response, properties, content = @channel.basic_get(@name, opts)

      if block
        if properties
          di = GetResponse.new(get_response, @channel)
          mp = MessageProperties.new(properties)

          block.call(di, mp, content)
        else
          block.call(nil, nil, nil)
        end
      else
        if properties
          di = GetResponse.new(get_response, @channel)
          mp = MessageProperties.new(properties)
          [di, mp, content]
        else
          [nil, nil, nil]
        end
      end
    end
    alias get pop

    # Publishes a message to the queue via default exchange. Takes the same arguments
    # as {Bunny::Exchange#publish}
    #
    # @see Bunny::Exchange#publish
    # @see Bunny::Channel#default_exchange
    # @see http://rubybunny.info/articles/exchanges.html Exchanges and Publishing guide
    def publish(payload, opts = {})
      @channel.default_exchange.publish(payload, opts.merge(:routing_key => @name))

      self
    end


    # Deletes the queue
    #
    # @param [Hash] opts Options
    #
    # @option opts [Boolean] if_unused (false) Should this queue be deleted only if it has no consumers?
    # @option opts [Boolean] if_empty (false) Should this queue be deleted only if it has no messages?
    #
    # @see http://rubybunny.info/articles/queues.html Queues and Consumers guide
    # @api public
    def delete(opts = {})
      @channel.deregister_queue(self)
      @channel.queue_delete(@name, opts)
    end

    # Purges a queue (removes all messages from it)
    # @see http://rubybunny.info/articles/queues.html Queues and Consumers guide
    # @api public
    def purge(opts = {})
      @channel.queue_purge(@name, opts)

      self
    end

    # @return [Hash] A hash with information about the number of queue messages and consumers
    # @see #message_count
    # @see #consumer_count
    def status
      queue_declare_ok = @channel.queue_declare(@name, @options.merge(:passive => true))
      {:message_count => queue_declare_ok.message_count,
        :consumer_count => queue_declare_ok.consumer_count}
    end

    # @return [Integer] How many messages the queue has ready (e.g. not delivered but not unacknowledged)
    def message_count
      s = self.status
      s[:message_count]
    end

    # @return [Integer] How many active consumers the queue has
    def consumer_count
      s = self.status
      s[:consumer_count]
    end

    #
    # Recovery
    #

    # @private
    def recover_from_network_failure
      if self.server_named?
        old_name = @name.dup
        @name    = AMQ::Protocol::EMPTY_STRING

        @channel.deregister_queue_named(old_name)
      end

      # TODO: inject and use logger
      # puts "Recovering queue #{@name}"
      begin
        declare! unless @options[:no_declare]

        @channel.register_queue(self)
      rescue Exception => e
        # TODO: inject and use logger
        puts "Caught #{e.inspect} while redeclaring and registering #{@name}!"
      end
      recover_bindings
    end

    # @private
    def recover_bindings
      @bindings.each do |b|
        # TODO: inject and use logger
        # puts "Recovering binding #{b.inspect}"
        self.bind(b[:exchange], b)
      end
    end


    #
    # Implementation
    #

    # @private
    def declare!
      queue_declare_ok = @channel.queue_declare(@name, @options)
      @name = queue_declare_ok.queue
    end

    protected

    # @private
    def self.add_default_options(name, opts, block)
      { :queue => name, :nowait => (block.nil? && !name.empty?) }.merge(opts)
    end

    # @private
    def self.add_default_options(name, opts)
      # :nowait is always false for Bunny
      h = { :queue => name, :nowait => false }.merge(opts)

      if name.empty?
        {
          :passive     => false,
          :durable     => false,
          :exclusive   => false,
          :auto_delete => false,
          :arguments   => nil
        }.merge(h)
      else
        h
      end
    end
  end
end
