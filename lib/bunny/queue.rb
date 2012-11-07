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

      @default_consumer = nil

      declare! unless opts[:no_declare]
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
    end


    # Deletes the queue
    # @api public
    def delete(opts = {})
      @channel.queue_delete(@name, opts)
    end


    #
    # Implementation
    #

    # @private
    def declare!
      queue_declare_ok = @channel.queue_declare(@name, @options)
      @name = queue_declare_ok.queue
    end

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
