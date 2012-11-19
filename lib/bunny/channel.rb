require "thread"
require "amq/int_allocator"

require "bunny/concurrent/condition"

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

      @announcer_thread    = Thread.new(&method(:announce_active_continuation))
    end

    def announce_active_continuation
      loop do
        puts "Active continuation is #{@active_continuation.inspect}" if @active_continuation

        sleep 5
      end
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

    def flow(active)
      channel_flow(active)
    end

    def recover(ignored = true)
      # RabbitMQ only supports basic.recover with requeue = true
      basic_recover(true)
    end

    def reject(delivery_tag, requeue = false)
      basic_reject(delivery_tag, requeue)
    end

    def ack(delivery_tag, multiple)
      basic_ack(delivery_tag, multiple)
    end
    alias acknowledge ack

    def on_error(&block)
      @default_error_handler = block
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

    def basic_get(queue, opts = {:ack => true})
      check_that_not_closed!

      @basic_get_continuation = Bunny::Concurrent::Condition.new("basic.get-ok/basic.get-empty")
      @connection.send_frame(AMQ::Protocol::Basic::Get.encode(@id, queue, !opts[:ack]))
      Bunny::Timer.timeout(1, ClientTimeout) do
        @basic_get_continuation.wait
      end

      raise_if_continuation_resulted_in_a_channel_error!
      @last_basic_get_response
    end

    def basic_qos(prefetch_count, global = false)
      raise ArgumentError.new("prefetch count must be a positive integer, given: #{prefetch_count}") if prefetch_count < 0
      check_that_not_closed!

      @basic_qos_continuation = Bunny::Concurrent::Condition.new("basic.qos-ok")
      @connection.send_frame(AMQ::Protocol::Basic::Qos.encode(@id, 0, prefetch_count, global))

      Bunny::Timer.timeout(1, ClientTimeout) do
        @basic_qos_continuation.wait
      end
      raise_if_continuation_resulted_in_a_channel_error!

      @last_basic_qos_ok
    end

    def basic_recover(requeue)
      check_that_not_closed!

      @basic_recover_continuation = Bunny::Concurrent::Condition.new("basic.recover-ok")
      @connection.send_frame(AMQ::Protocol::Basic::Recover.encode(@id, requeue))

      Bunny::Timer.timeout(1, ClientTimeout) do
        @basic_recover_continuation.wait
      end
      raise_if_continuation_resulted_in_a_channel_error!

      @last_basic_recover_ok
    end

    def basic_reject(delivery_tag, requeue)
      check_that_not_closed!
      @connection.send_frame(AMQ::Protocol::Basic::Reject.encode(@id, delivery_tag, requeue))

      nil
    end

    def basic_ack(delivery_tag, multiple)
      check_that_not_closed!
      @connection.send_frame(AMQ::Protocol::Basic::Ack.encode(@id, delivery_tag, multiple))

      nil
    end


    # queue.*

    def queue_declare(name, opts = {})
      check_that_not_closed!

      @queue_declare_continuation = Bunny::Concurrent::Condition.new("queue.declare-ok")
      @active_continuation        = @queue_declare_continuation
      @connection.send_frame(AMQ::Protocol::Queue::Declare.encode(@id, name, opts.fetch(:passive, false), opts.fetch(:durable, false), opts.fetch(:exclusive, false), opts.fetch(:auto_delete, false), false, opts[:arguments]))

      Bunny::Timer.timeout(1, ClientTimeout) do
        @queue_declare_continuation.wait
      end
      raise_if_continuation_resulted_in_a_channel_error!

      @last_queue_declare_ok
    end

    def queue_delete(name, opts = {})
      check_that_not_closed!

      @queue_delete_continuation = Bunny::Concurrent::Condition.new("queue.delete-ok")
      @active_continuation       = @queue_delete_continuation
      @connection.send_frame(AMQ::Protocol::Queue::Delete.encode(@id, name, opts[:if_unused], opts[:if_empty], false))

      Bunny::Timer.timeout(1, ClientTimeout) do
        @queue_delete_continuation.wait
      end
      raise_if_continuation_resulted_in_a_channel_error!

      @last_queue_delete_ok
    end

    def queue_purge(name, opts = {})
      check_that_not_closed!

      @queue_purge_continuation = Bunny::Concurrent::Condition.new("queue.purge-ok")
      @active_continuation      = @queue_purge_continuation
      @connection.send_frame(AMQ::Protocol::Queue::Purge.encode(@id, name, false))

      Bunny::Timer.timeout(1, ClientTimeout) do
        @queue_purge_continuation.wait
      end
      raise_if_continuation_resulted_in_a_channel_error!

      @last_queue_purge_ok
    end

    def queue_bind(name, exchange, opts = {})
      check_that_not_closed!

      exchange_name = if exchange.respond_to?(:name)
                        exchange.name
                      else
                        exchange
                      end

      @queue_bind_continuation = Bunny::Concurrent::Condition.new("queue.bind-ok")
      @active_continuation     = @queue_bind_continuation
      @connection.send_frame(AMQ::Protocol::Queue::Bind.encode(@id, name, exchange_name, opts[:routing_key], false, opts[:arguments]))

      Bunny::Timer.timeout(1, ClientTimeout) do
        @queue_bind_continuation.wait
      end

      raise_if_continuation_resulted_in_a_channel_error!
      @last_queue_bind_ok
    end

    def queue_unbind(name, exchange, opts = {})
      check_that_not_closed!

      exchange_name = if exchange.respond_to?(:name)
                        exchange.name
                      else
                        exchange
                      end

      @queue_unbind_continuation = Bunny::Concurrent::Condition.new("queue.unbind-ok")
      @active_continuation       = @queue_unbind_continuation
      @connection.send_frame(AMQ::Protocol::Queue::Unbind.encode(@id, name, exchange_name, opts[:routing_key], opts[:arguments]))

      Bunny::Timer.timeout(1, ClientTimeout) do
        @queue_unbind_continuation.wait
      end

      raise_if_continuation_resulted_in_a_channel_error!
      @last_queue_unbind_ok
    end


    # exchange.*

    def exchange_declare(name, type, opts = {})
      check_that_not_closed!

      @exchange_declare_continuation = Bunny::Concurrent::Condition.new("exchange.declare-ok")
      @active_continuation           = @exchange_declare_continuation
      @connection.send_frame(AMQ::Protocol::Exchange::Declare.encode(@id, name, type.to_s, opts.fetch(:passive, false), opts.fetch(:durable, false), opts.fetch(:auto_delete, false), false, false, opts[:arguments]))

      Bunny::Timer.timeout(1, ClientTimeout) do
        @exchange_declare_continuation.wait
      end

      raise_if_continuation_resulted_in_a_channel_error!
      @last_exchange_declare_ok
    end

    def exchange_delete(name, opts = {})
      check_that_not_closed!

      @exchange_delete_continuation = Bunny::Concurrent::Condition.new("exchange.delete-ok")
      @active_continuation           = @exchange_delete_continuation
      @connection.send_frame(AMQ::Protocol::Exchange::Delete.encode(@id, name, opts[:if_unused], false))

      Bunny::Timer.timeout(1, ClientTimeout) do
        @exchange_delete_continuation.wait
      end

      raise_if_continuation_resulted_in_a_channel_error!
      @last_exchange_delete_ok
    end

    # channel.*

    def channel_flow(active)
      check_that_not_closed!

      @channel_flow_continuation = Bunny::Concurrent::Condition.new("channel.flow-ok")
      @active_continuation       = @channel_flow_continuation
      @connection.send_frame(AMQ::Protocol::Channel::Flow.encode(@id, active))

      Bunny::Timer.timeout(1, ClientTimeout) do
        @channel_flow_continuation.wait
      end
      raise_if_continuation_resulted_in_a_channel_error!

      @last_channel_flow_ok
    end


    #
    # Implementation
    #

    def handle_method(method)
      # puts "Channel#handle_frame: #{method.inspect}, @active_continuation: #{@active_continuation.inspect}"
      case method
      when AMQ::Protocol::Queue::DeclareOk then
        @last_queue_declare_ok = method
        @queue_declare_continuation.notify_all

        @queue_declare_continuation = nil
        @active_continuation        = nil
      when AMQ::Protocol::Queue::DeleteOk then
        @last_queue_delete_ok = method
        @queue_delete_continuation.notify_all

        @queue_delete_continuation = nil
        @active_continuation       = nil
      when AMQ::Protocol::Queue::PurgeOk then
        @last_queue_purge_ok = method
        @queue_purge_continuation.notify_all

        @queue_purge_continuation = nil
        @active_continuation      = nil
      when AMQ::Protocol::Queue::BindOk then
        @last_queue_bind_ok = method
        @queue_bind_continuation.notify_all

        @queue_bind_continuation = nil
        @active_continuation     = nil
      when AMQ::Protocol::Queue::UnbindOk then
        @last_queue_unbind_ok = method
        @queue_unbind_continuation.notify_all

        @queue_unbind_continuation = nil
        @active_continuation       = nil
      when AMQ::Protocol::Exchange::DeclareOk then
        @last_exchange_declare_ok = method
        @exchange_declare_continuation.notify_all

        @exchange_declare_continuation = nil
        @active_continuation           = nil
      when AMQ::Protocol::Exchange::DeleteOk then
        @last_exchange_delete_ok = method
        @exchange_delete_continuation.notify_all

        @exchange_delete_continuation = nil
        @active_continuation          = nil
      when AMQ::Protocol::Basic::QosOk then
        @last_basic_qos_ok = method
        @basic_qos_continuation.notify_all

        @exchange_qos_continuation = nil
        @active_continuation       = nil
      when AMQ::Protocol::Basic::RecoverOk then
        @last_basic_recover_ok = method
        @basic_recover_continuation.notify_all

        @exchange_recover_continuation = nil
        @active_continuation           = nil
      when AMQ::Protocol::Channel::FlowOk then
        @last_channel_flow_ok = method
        @channel_flow_continuation.notify_all

        @channel_flow_continuation = nil
        @active_continuation       = nil
      when AMQ::Protocol::Channel::Close then
        closed!
        @connection.send_frame(AMQ::Protocol::Channel::CloseOk.encode(@id))

        @last_channel_error = instantiate_channel_level_exception(method)
        @active_continuation.notify_all if @active_continuation
        @active_continuation = nil
      when AMQ::Protocol::Channel::CloseOk then
        @last_channel_close_ok = method
      else
        raise "Do not know how to handle #{method.inspect} in Bunny::Channel#handle_method"
      end
    end

    def handle_basic_get_ok(basic_get_ok, header, content)
      envelope = {:delivery_tag => basic_get_ok.delivery_tag, :redelivered => basic_get_ok.redelivered, :exchange => basic_get_ok.exchange, :routing_key => basic_get_ok.routing_key, :message_count => basic_get_ok.message_count}

      @last_basic_get_response = Hash[:header           => header.decode_payload,
                                      :payload          => content,
                                      :delivery_details => envelope]

      @basic_get_continuation.notify_all
    end

    def handle_basic_get_empty(basic_get_empty)
      @last_basic_get_response = {:header => nil, :payload => :queue_empty, :delivery_details => nil}
      @basic_get_continuation.notify_all
    end

    def maybe_notify_active_continuation!
      @active_continuation.notify_all if @active_continuation
    end

    def maybe_clear_active_continuation!
      if @active_continuation
        @active_continuation.notify_all
        @active_continuation = nil
      end
    end

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

      @announcer_thread.kill if @announcer_thread
    end

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

    def raise_if_continuation_resulted_in_a_channel_error!
      raise @last_channel_error if @last_channel_error
    end

    def check_that_not_closed!
      raise ChannelAlreadyClosed.new("cannot use a channel that was already closed! Channel id: #{@id}", self) if closed?
    end
  end
end
