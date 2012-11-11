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
      @id         = id || @connection.next_channel_id
      @status     = :opening

      @connection.register_channel(self)

      @queues     = Hash.new
      @exchanges  = Hash.new
      @consumers  = Hash.new

      # synchronizes frameset delivery. MK.
      @mutex     = Mutex.new
    end


    def open
      @connection.open_channel(self)
      @status = :open
    end

    def close
      @connection.close_channel(self)
      closed!
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

    def frame_size
      @connection.frame_max
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

    def default_exchange
      self.direct("", :no_declare => true)
    end

    def prefetch(prefetch_count)
      self.basic_qos(prefetch_count, false)
    end


    #
    # Lower-level API, exposes protocol operations as they are defined in the protocol,
    # without any OO sugar on top, by design.
    #

    # basic.*

    def basic_publish(payload, exchange, routing_key, opts = {})
      check_that_not_closed!

      exchange_name = if exchange.respond_to?(:name)
                        exchange.name
                      else
                        exchange
                      end

      meta = { :priority => 0, :delivery_mode => 2, :content_type => "application/octet-stream" }.
        merge(opts)
      @connection.send_frameset(AMQ::Protocol::Basic::Publish.encode(@id, payload, meta, @name, routing_key, meta[:mandatory], false, (frame_size || @connection.frame_max)), self)

      self
    end

    def basic_get(queue)
      check_that_not_closed!

      @connection.send_frame(AMQ::Protocol::Basic::Get.encode(@id, queue, false))

      frame = @connection.read_next_frame.decode_payload
      check_for_channel_level_exception!(frame)
      frame
    end

    def basic_qos(prefetch_count, global = false)
      raise ArgumentError.new("prefetch count must be a positive integer, given: #{prefetch_count}") if prefetch_count < 0
      check_that_not_closed!

      @connection.send_frame(AMQ::Protocol::Basic::Qos.encode(@id, 0, prefetch_count, global))

      frame = @connection.read_next_frame.decode_payload
      check_for_channel_level_exception!(frame)
      frame      
    end


    # queue.*

    def queue_declare(name, opts = {})
      check_that_not_closed!

      @connection.send_frame(AMQ::Protocol::Queue::Declare.encode(@id, name, opts.fetch(:passive, false), opts.fetch(:durable, false), opts.fetch(:exclusive, false), opts.fetch(:auto_delete, false), false, opts[:arguments]))

      frame = @connection.read_next_frame.decode_payload
      check_for_channel_level_exception!(frame)
      frame
    end

    def queue_delete(name, opts = {})
      check_that_not_closed!

      @connection.send_frame(AMQ::Protocol::Queue::Delete.encode(@id, name, opts[:if_unused], opts[:if_empty], false))

      frame = @connection.read_next_frame.decode_payload
      check_for_channel_level_exception!(frame)
      frame
    end

    def queue_bind(name, exchange, opts = {})
      check_that_not_closed!

      exchange_name = if exchange.respond_to?(:name)
                        exchange.name
                      else
                        exchange
                      end

      @connection.send_frame(AMQ::Protocol::Queue::Bind.encode(@id, name, exchange_name, opts[:routing_key], false, opts[:arguments]))

      frame = @connection.read_next_frame.decode_payload
      check_for_channel_level_exception!(frame)
      frame
    end

    def queue_unbind(name, exchange, opts = {})
      check_that_not_closed!

      exchange_name = if exchange.respond_to?(:name)
                        exchange.name
                      else
                        exchange
                      end

      @connection.send_frame(AMQ::Protocol::Queue::Unbind.encode(@id, name, exchange_name, opts[:routing_key], opts[:arguments]))

      frame = @connection.read_next_frame.decode_payload
      check_for_channel_level_exception!(frame)
      frame
    end


    # exchange.*

    def exchange_declare(name, type, opts = {})
      check_that_not_closed!

      @connection.send_frame(AMQ::Protocol::Exchange::Declare.encode(@id, name, type.to_s, opts.fetch(:passive, false), opts.fetch(:durable, false), opts.fetch(:auto_delete, false), false, false, opts[:arguments]))

      frame = @connection.read_next_frame.decode_payload
      check_for_channel_level_exception!(frame)
      frame
    end

    def exchange_delete(name, opts = {})
      check_that_not_closed!

      @connection.send_frame(AMQ::Protocol::Exchange::Delete.encode(@id, name, opts[:if_unused], false))

      frame = @connection.read_next_frame.decode_payload
      check_for_channel_level_exception!(frame)
      frame
    end



    #
    # Implementation
    #

    def read_next_frame(options = {})
      @connection.read_next_frame(options = {})
    end

    # Synchronizes given block using this channel's mutex.
    # @api public
    def synchronize(&block)
      @mutex.synchronize(&block)
    end

    def register_queue(queue)
      @queues[queue.name] = queue
    end

    def find_queue(name, opts = {})
      @queues[name]
    end

    protected

    def closed!
      @status = :closed
      @connection.release_channel_id(@id)
    end

    def check_for_channel_level_exception!(frame)
      case frame
      when AMQ::Protocol::Channel::Close then
        closed!

        @connection.send_frame(AMQ::Protocol::Channel::CloseOk.encode(@id))

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

        raise klass.new(frame.reply_text, self, frame)
      end
    end

    def check_that_not_closed!
      raise ChannelAlreadyClosed.new("cannot use a channel that was already closed! Channel id: #{@id}", self) if closed?
    end
  end
end
