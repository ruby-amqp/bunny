require "bunny/compatibility"

module Bunny
  class Queue

    include Bunny::Compatibility


    #
    # API
    #

    attr_reader :channel, :name, :options

    def initialize(channel_or_connection, name = AMQ::Protocol::EMPTY_STRING, opts = {})
      # old Bunny versions pass a connection here. In that case,
      # we just use default channel from it. MK.
      @channel          = channel_from(channel_or_connection)
      @name             = name
      @options          = self.class.add_default_options(name, opts)
      @consumers        = Hash.new

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
    def durable?
      @durable
    end # durable?

    # @return [Boolean] true if this queue was declared as exclusive (limited to just one consumer)
    # @api public
    def exclusive?
      @exclusive
    end # exclusive?

    # @return [Boolean] true if this queue was declared as automatically deleted (deleted as soon as last consumer unbinds).
    # @api public
    def auto_delete?
      @auto_delete
    end # auto_delete?

    # @return [Boolean] true if this queue was declared as server named.
    # @api public
    def server_named?
      @server_named
    end # server_named?

    def arguments
      @arguments
    end


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

    def subscribe(opts = {
                    :consumer_tag    => @channel.generate_consumer_tag,
                    :ack             => false,
                    :exclusive       => false,
                    :block           => false,
                    :on_cancellation => nil
                  }, &block)

      ctag       = opts.fetch(:consumer_tag, @channel.generate_consumer_tag)
      consumer   = Consumer.new(@channel,
                                @name,
                                ctag,
                                !opts[:ack],
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

    def subscribe_with(consumer, opts = {:block => false})
      @channel.basic_consume_with(consumer)

      @channel.work_pool.join if opts[:block]
      consumer
    end

    def pop(opts = {:ack => false}, &block)
      delivery_info, properties, content = @channel.basic_get(@name, opts)

      if block
        block.call(delivery_info, properties, content)
      else
        [delivery_info, properties, content]
      end
    end
    alias get pop

    def pop_as_hash(opts = {:ack => false}, &block)
      delivery_info, properties, content = @channel.basic_get(@name, opts)

      result = {:header => properties, :payload => content, :delivery_details => delivery_info}

      if block
        block.call(result)
      else
        result
      end
    end

    # Publishes a message to the queue via default exchange.
    #
    # @see Bunny::Exchange#publish
    # @see Bunny::Channel#default_exchange
    def publish(payload, opts = {})
      @channel.default_exchange.publish(payload, opts.merge(:routing_key => @name))

      self
    end


    # Deletes the queue
    # @api public
    def delete(opts = {})
      @channel.deregister_queue(self)
      @channel.queue_delete(@name, opts)
    end

    def purge(opts = {})
      @channel.queue_purge(@name, opts)

      self
    end

    def status
      queue_declare_ok = @channel.queue_declare(@name, @options.merge(:passive => true))
      {:message_count => queue_declare_ok.message_count,
        :consumer_count => queue_declare_ok.consumer_count}
    end

    def message_count
      s = self.status
      s[:message_count]
    end

    def consumer_count
      s = self.status
      s[:consumer_count]
    end

    #
    # Recovery
    #

    def recover_from_network_failure
      # puts "Recovering queue #{@name} from network failure"

      if self.server_named?
        old_name = @name.dup
        @name    = AMQ::Protocol::EMPTY_STRING

        @channel.deregister_queue_named(old_name)
      end

      declare!
      begin
        @channel.register_queue(self)
      rescue Exception => e
        puts "Caught #{e.inspect} while registering #{@name}!"
      end
      recover_bindings
    end

    def recover_bindings
      @bindings.each do |b|
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
