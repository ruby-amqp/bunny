module Bunny
  class Queue

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

      @default_consumer = nil

      declare!
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


    def delete(opts = {})
      queue_delete_ok = @channel.queue_delete(@name, opts)
    end


    #
    # Implementation
    #

    def declare!
      queue_declare_ok = @channel.queue_declare(@name, @options)
      @name = queue_declare_ok.queue
    end

    def channel_from(channel_or_connection)
      if channel_or_connection.is_a?(Bunny::Session)
        channel_or_connection.default_channel
      else
        channel_or_connection
      end
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
          :exclusive   => true,
          :auto_delete => true,
          :arguments   => nil
        }.merge(h)
      else
        h
      end
    end
  end
end
