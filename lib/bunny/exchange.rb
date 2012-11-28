require "bunny/compatibility"

module Bunny
  class Exchange

    include Bunny::Compatibility


    #
    # API
    #

    # @return [Bunny::Channel]
    attr_reader :channel

    # @return [String]
    attr_reader :name

    # Type of this exchange (one of: :direct, :fanout, :topic, :headers).
    # @return [Symbol]
    attr_reader :type

    # @return [Symbol]
    # @api plugin
    attr_reader :status

    # Options hash this exchange instance was instantiated with
    # @return [Hash]
    attr_accessor :opts


    # The default exchange. Default exchange is a direct exchange that is predefined.
    # It cannot be removed. Every queue is bind to this (direct) exchange by default with
    # the following routing semantics: messages will be routed to the queue withe same
    # same name as message's routing key. In other words, if a message is published with
    # a routing key of "weather.usa.ca.sandiego" and there is a queue Q with this name,
    # that message will be routed to Q.
    #
    # @param [Bunny::Channel] channel Channel to use.
    #
    # @example Publishing a messages to the tasks queue
    #   channel     = Bunny::Channel.new(connection)
    #   tasks_queue = channel.queue("tasks")
    #   Bunny::Exchange.default(channel).publish("make clean", routing_key => "tasks")
    #
    # @see Exchange
    # @see http://files.travis-ci.org/docs/amqp/0.9.1/AMQP091Specification.pdf AMQP 0.9.1 specification (Section 2.1.2.4)
    # @note Do not confuse default exchange with amq.direct: amq.direct is a pre-defined direct
    #       exchange that doesn't have any special routing semantics.
    # @return [Exchange] An instance that corresponds to the default exchange (of type direct).
    # @api public
    def self.default(channel_or_connection)
      self.new(channel_from(channel_or_connection), :direct, AMQ::Protocol::EMPTY_STRING, :no_declare => true)
    end


    def initialize(channel_or_connection, type, name, opts = {})
      # old Bunny versions pass a connection here. In that case,
      # we just use default channel from it. MK.
      @channel          = channel_from(channel_or_connection)
      @name             = name
      @type             = type
      @options          = self.class.add_default_options(name, opts)

      @durable          = @options[:durable]
      @auto_delete      = @options[:auto_delete]
      @arguments        = @options[:arguments]

      declare! unless opts[:no_declare] || (@name =~ /^amq\..+/) || (@name == AMQ::Protocol::EMPTY_STRING)

      @channel.register_exchange(self)
    end

    # @return [Boolean] true if this exchange was declared as durable (will survive broker restart).
    # @api public
    def durable?
      @durable
    end # durable?

    # @return [Boolean] true if this exchange was declared as automatically deleted (deleted as soon as last consumer unbinds).
    # @api public
    def auto_delete?
      @auto_delete
    end # auto_delete?

    def arguments
      @arguments
    end



    def publish(payload, opts = {})
      @channel.basic_publish(payload, self.name, (opts.delete(:routing_key) || opts.delete(:key)), opts)

      self
    end


    # Deletes the exchange
    # @api public
    def delete(opts = {})
      @channel.exchange_delete(@name, opts)
    end


    def bind(source, opts = {})
      @channel.exchange_bind(source, self, opts)
    end

    def unbind(source, opts = {})
      @channel.exchange_unbind(source, self, opts)
    end


    def on_return(&block)
      @on_return = block
    end


    #
    # Implementation
    #

    def handle_return(basic_return, properties, content)
      if @on_return
        @on_return.call(basic_return, properties, content)
      else
        # TODO: log a warning
      end
    end

    protected

    # @private
    def declare!
      @channel.exchange_declare(@name, @type, @options)
    end

    # @private
    def self.add_default_options(name, opts, block)
      { :exchange => name, :nowait => (block.nil? && !name.empty?) }.merge(opts)
    end

    # @private
    def self.add_default_options(name, opts)
      # :nowait is always false for Bunny
      h = { :queue => name, :nowait => false }.merge(opts)

      if name.empty?
        {
          :passive     => false,
          :durable     => false,
          :auto_delete => false,
          :arguments   => nil
        }.merge(h)
      else
        h
      end
    end
  end
end
