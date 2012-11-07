require "thread"
require "amq/int_allocator"

require "bunny/exchange"
require "bunny/queue"

module Bunny
  class Channel

    #
    # API
    #

    attr_accessor :id, :connection, :status


    def initialize(connection = nil, id = nil)
      @connection = connection
      @id         = id || self.class.next_channel_id
      @status     = :opening

      @connection.register_channel(self)

      @queues     = Hash.new
      @exchanges  = Hash.new
      @consumers  = Hash.new
    end


    def open
      @connection.open_channel(self)
      @status = :open
    end

    def close
      @connection.close_channel(self)
      @status = :closed
      self.class.release_channel_id(@id)
    end

    def open?
      @status == :open
    end

    def closed?
      @status == :closed
    end

    def queue(name = AMQ::Protocol::EMPTY_STRING, opts = {})
      q = find_queue(name, opts) || Bunny::Queue.new(self, name, opts)

      register_queue(q)
    end


    #
    # Backwards compatibility with 0.8.0
    #

    def number
      self.id
    end

    def active
      @active
    end

    def client
      @connection
    end



    #
    # Higher-level API, similar to amqp gem
    #

    def fanout(name, opts = {})
      Exchange.new(self, :fanout, name, opts)
    end

    def direct(name, opts = {})
      Exchange.new(self, :direct, name, opts)
    end

    def topic(name, opts = {})
      Exchange.new(self, :topic, name, opts)
    end

    def headers(name, opts = {})
      Exchange.new(self, :headers, name, opts)
    end


    #
    # Lower-level API, exposes protocol operations as they are defined in the protocol,
    # without any OO sugar on top, by design.
    #

    # queue.*

    def queue_declare(name, opts = {})
      @connection.send_frame(AMQ::Protocol::Queue::Declare.encode(@id, name, opts.fetch(:passive, false), opts.fetch(:durable, false), opts.fetch(:exclusive, false), opts.fetch(:auto_delete, false), false, opts[:arguments]))

      frame = @connection.read_next_frame
      frame.decode_payload
    end

    def queue_delete(name, opts = {})
      @connection.send_frame(AMQ::Protocol::Queue::Delete.encode(@id, name, opts[:if_unused], opts[:if_empty], false))

      frame = @connection.read_next_frame
      frame.decode_payload
    end

    def queue_bind(name, exchange, opts = {})
      raise NotImplementedError
    end


    # exchange.*

    def exchange_declare(name, type, opts = {})
      @connection.send_frame(AMQ::Protocol::Exchange::Declare.encode(@id, name, type.to_s, opts.fetch(:passive, false), opts.fetch(:durable, false), opts.fetch(:auto_delete, false), false, false, opts[:arguments]))

      frame = @connection.read_next_frame
      frame.decode_payload      
    end

    def exchange_delete(name, opts = {})
      @connection.send_frame(AMQ::Protocol::Exchange::Delete.encode(@id, name, opts[:if_unused], false))

      frame = @connection.read_next_frame
      frame.decode_payload      
    end




    #
    # Implementation
    #

    def register_queue(queue)
      @queues[queue.name] = queue
    end

    def find_queue(name, opts = {})
      @queues[name]
    end


    # @private
    # @api private
    def self.channel_id_mutex
      @channel_id_mutex ||= Mutex.new
    end

    # Returns next available channel id. This method is thread safe.
    #
    # @return [Fixnum]
    # @api public
    # @see Channel.release_channel_id
    # @see Channel.reset_channel_id_allocator
    def self.next_channel_id
      channel_id_mutex.synchronize do
        self.initialize_channel_id_allocator

        @int_allocator.allocate
      end
    end

    # Releases previously allocated channel id. This method is thread safe.
    #
    # @param [Fixnum] Channel id to release
    # @api public
    # @see Channel.next_channel_id
    # @see Channel.reset_channel_id_allocator
    def self.release_channel_id(i)
      channel_id_mutex.synchronize do
        self.initialize_channel_id_allocator

        @int_allocator.release(i)
      end
    end # self.release_channel_id(i)

    # Resets channel allocator. This method is thread safe.
    # @api public
    # @see Channel.next_channel_id
    # @see Channel.release_channel_id
    def self.reset_channel_id_allocator
      channel_id_mutex.synchronize do
        self.initialize_channel_id_allocator

        @int_allocator.reset
      end
    end # self.reset_channel_id_allocator


    # @private
    def self.initialize_channel_id_allocator
      # TODO: ideally, this should be in agreement with negotiated max number of channels of the connection,
      #       but it is possible that the value is not yet available. MK.
      max_channel     =  (1 << 16) - 1
      @int_allocator ||= AMQ::IntAllocator.new(1, max_channel)
    end # self.initialize_channel_id_allocator
  end
end
