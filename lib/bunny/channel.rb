require "thread"
require "amq/int_allocator"

require "bunny/consumer_work_pool"

require "bunny/exchange"
require "bunny/queue"
require "bunny/message_metadata"

module Bunny
  class Channel

    #
    # API
    #

    attr_accessor :id, :connection, :status, :work_pool


    def initialize(connection = nil, id = nil, work_pool = ConsumerWorkPool.new(1))
      @connection = connection
      @id         = id || @connection.next_channel_id
      @status     = :opening

      @connection.register_channel(self)

      @queues     = Hash.new
      @exchanges  = Hash.new
      @consumers  = Hash.new
      @work_pool  = work_pool

      # synchronizes frameset delivery. MK.
      @mutex          = Mutex.new
      @consumer_mutex = Mutex.new

      @continuations = ::Queue.new
    end


    def open
      @connection.open_channel(self)
      @status = :open

      self
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
      q = find_queue(name) || Bunny::Queue.new(self, name, opts)

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

    def nack(delivery_tag, requeue, multiple = false)
      basic_nack(delivery_tag, requeue, multiple)
    end

    def on_error(&block)
      @default_error_handler = block
    end


    #
    # Lower-level API, exposes protocol operations as they are defined in the protocol,
    # without any OO sugar on top, by design.
    #

    # basic.*

    def basic_publish(payload, exchange, routing_key, opts = {})
      raise_if_no_longer_open!

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
      raise_if_no_longer_open!

      @connection.send_frame(AMQ::Protocol::Basic::Get.encode(@id, queue, !opts[:ack]))
      @last_basic_get_response = @continuations.pop

      raise_if_continuation_resulted_in_a_channel_error!
      @last_basic_get_response
    end

    def basic_qos(prefetch_count, global = false)
      raise ArgumentError.new("prefetch count must be a positive integer, given: #{prefetch_count}") if prefetch_count < 0
      raise_if_no_longer_open!

      @connection.send_frame(AMQ::Protocol::Basic::Qos.encode(@id, 0, prefetch_count, global))

      Bunny::Timer.timeout(1, ClientTimeout) do
        @last_basic_qos_ok = @continuations.pop
      end
      raise_if_continuation_resulted_in_a_channel_error!

      @last_basic_qos_ok
    end

    def basic_recover(requeue)
      raise_if_no_longer_open!

      @connection.send_frame(AMQ::Protocol::Basic::Recover.encode(@id, requeue))
      Bunny::Timer.timeout(1, ClientTimeout) do
        @last_basic_recover_ok = @continuations.pop
      end
      raise_if_continuation_resulted_in_a_channel_error!

      @last_basic_recover_ok
    end

    def basic_reject(delivery_tag, requeue)
      raise_if_no_longer_open!
      @connection.send_frame(AMQ::Protocol::Basic::Reject.encode(@id, delivery_tag, requeue))

      nil
    end

    def basic_ack(delivery_tag, multiple)
      raise_if_no_longer_open!
      @connection.send_frame(AMQ::Protocol::Basic::Ack.encode(@id, delivery_tag, multiple))

      nil
    end

    def basic_nack(delivery_tag, requeue, multiple = false)
      raise_if_no_longer_open!
      @connection.send_frame(AMQ::Protocol::Basic::Nack.encode(@id, delivery_tag, requeue, multiple))

      nil
    end

    def basic_consume(queue, consumer_tag = generate_consumer_tag, no_ack = false, exclusive = false, arguments = nil, &block)
      raise_if_no_longer_open!
      maybe_start_consumer_work_pool!

      queue_name = if queue.respond_to?(:name)
                     queue.name
                   else
                     queue
                   end

      @connection.send_frame(AMQ::Protocol::Basic::Consume.encode(@id, queue_name, consumer_tag, false, no_ack, exclusive, false, arguments))
      Bunny::Timer.timeout(1, ClientTimeout) do
        @last_basic_consume_ok = @continuations.pop
      end

      @consumer_mutex.synchronize do
        c = Consumer.new(self, queue, consumer_tag, no_ack, exclusive, arguments)
        c.on_delivery(&block) if block

        @consumers[@last_basic_consume_ok.consumer_tag] = c
      end

      @last_basic_consume_ok
    end

    def basic_cancel(consumer_tag)
      @connection.send_frame(AMQ::Protocol::Basic::Cancel.encode(@id, consumer_tag, false))

      Bunny::Timer.timeout(1, ClientTimeout) do
        @last_basic_cancel_ok = @continuations.pop
      end

      @last_basic_cancel_ok
    end


    # queue.*

    def queue_declare(name, opts = {})
      raise_if_no_longer_open!

      @connection.send_frame(AMQ::Protocol::Queue::Declare.encode(@id, name, opts.fetch(:passive, false), opts.fetch(:durable, false), opts.fetch(:exclusive, false), opts.fetch(:auto_delete, false), false, opts[:arguments]))
      @last_queue_declare_ok = @continuations.pop

      raise_if_continuation_resulted_in_a_channel_error!

      @last_queue_declare_ok
    end

    def queue_delete(name, opts = {})
      raise_if_no_longer_open!

      @connection.send_frame(AMQ::Protocol::Queue::Delete.encode(@id, name, opts[:if_unused], opts[:if_empty], false))
      Bunny::Timer.timeout(1, ClientTimeout) do
        @last_queue_delete_ok = @continuations.pop
      end
      raise_if_continuation_resulted_in_a_channel_error!

      @last_queue_delete_ok
    end

    def queue_purge(name, opts = {})
      raise_if_no_longer_open!

      @connection.send_frame(AMQ::Protocol::Queue::Purge.encode(@id, name, false))

      Bunny::Timer.timeout(1, ClientTimeout) do
        @last_queue_purge_ok = @continuations.pop
      end
      raise_if_continuation_resulted_in_a_channel_error!

      @last_queue_purge_ok
    end

    def queue_bind(name, exchange, opts = {})
      raise_if_no_longer_open!

      exchange_name = if exchange.respond_to?(:name)
                        exchange.name
                      else
                        exchange
                      end

      @connection.send_frame(AMQ::Protocol::Queue::Bind.encode(@id, name, exchange_name, opts[:routing_key], false, opts[:arguments]))
      Bunny::Timer.timeout(1, ClientTimeout) do
        @last_queue_bind_ok = @continuations.pop
      end

      raise_if_continuation_resulted_in_a_channel_error!
      @last_queue_bind_ok
    end

    def queue_unbind(name, exchange, opts = {})
      raise_if_no_longer_open!

      exchange_name = if exchange.respond_to?(:name)
                        exchange.name
                      else
                        exchange
                      end

      @connection.send_frame(AMQ::Protocol::Queue::Unbind.encode(@id, name, exchange_name, opts[:routing_key], opts[:arguments]))
      Bunny::Timer.timeout(1, ClientTimeout) do
        @last_queue_unbind_ok = @continuations.pop
      end

      raise_if_continuation_resulted_in_a_channel_error!
      @last_queue_unbind_ok
    end


    # exchange.*

    def exchange_declare(name, type, opts = {})
      raise_if_no_longer_open!

      @connection.send_frame(AMQ::Protocol::Exchange::Declare.encode(@id, name, type.to_s, opts.fetch(:passive, false), opts.fetch(:durable, false), opts.fetch(:auto_delete, false), false, false, opts[:arguments]))
      Bunny::Timer.timeout(1, ClientTimeout) do
        @last_exchange_declare_ok = @continuations.pop
      end

      raise_if_continuation_resulted_in_a_channel_error!
      @last_exchange_declare_ok
    end

    def exchange_delete(name, opts = {})
      raise_if_no_longer_open!

      @connection.send_frame(AMQ::Protocol::Exchange::Delete.encode(@id, name, opts[:if_unused], false))
      Bunny::Timer.timeout(1, ClientTimeout) do
        @last_exchange_delete_ok = @continuations.pop
      end

      raise_if_continuation_resulted_in_a_channel_error!
      @last_exchange_delete_ok
    end

    # channel.*

    def channel_flow(active)
      raise_if_no_longer_open!

      @connection.send_frame(AMQ::Protocol::Channel::Flow.encode(@id, active))
      Bunny::Timer.timeout(1, ClientTimeout) do
        @last_channel_flow_ok = @continuations.pop
      end
      raise_if_continuation_resulted_in_a_channel_error!

      @last_channel_flow_ok
    end

    # tx.*

    def tx_select
      raise_if_no_longer_open!

      @connection.send_frame(AMQ::Protocol::Tx::Select.encode(@id))
      Bunny::Timer.timeout(1, ClientTimeout) do
        @last_tx_select_ok = @continuations.pop
      end
      raise_if_continuation_resulted_in_a_channel_error!

      @last_tx_select_ok
    end

    def tx_commit
      raise_if_no_longer_open!

      @connection.send_frame(AMQ::Protocol::Tx::Commit.encode(@id))
      Bunny::Timer.timeout(1, ClientTimeout) do
        @last_tx_commit_ok = @continuations.pop
      end
      raise_if_continuation_resulted_in_a_channel_error!

      @last_tx_commit_ok
    end

    def tx_rollback
      raise_if_no_longer_open!

      @connection.send_frame(AMQ::Protocol::Tx::Rollback.encode(@id))
      Bunny::Timer.timeout(1, ClientTimeout) do
        @last_tx_rollback_ok = @continuations.pop
      end
      raise_if_continuation_resulted_in_a_channel_error!

      @last_tx_rollback_ok
    end


    #
    # Implementation
    #

    def handle_method(method)
      # puts "Channel#handle_frame on channel #{@id}: #{method.inspect}"
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
      when AMQ::Protocol::Basic::CancelOk then
        @continuations.push(method)
        # TODO: cancel the consumer
      when AMQ::Protocol::Tx::SelectOk, AMQ::Protocol::Tx::CommitOk, AMQ::Protocol::Tx::RollbackOk then
        @continuations.push(method)
      when AMQ::Protocol::Tx::SelectOk then
        @continuations.push(method)
      when AMQ::Protocol::Channel::Close then
        # puts "Exception on channel #{@id}: #{method.reply_code} #{method.reply_text}"
        closed!
        @connection.send_frame(AMQ::Protocol::Channel::CloseOk.encode(@id))

        @last_channel_error = instantiate_channel_level_exception(method)
        @continuations.push(method)
      when AMQ::Protocol::Channel::CloseOk then
        @continuations.push(method)
      else
        raise "Do not know how to handle #{method.inspect} in Bunny::Channel#handle_method"
      end
    end

    def handle_basic_get_ok(basic_get_ok, header, content)
      envelope = {:delivery_tag => basic_get_ok.delivery_tag, :redelivered => basic_get_ok.redelivered, :exchange => basic_get_ok.exchange, :routing_key => basic_get_ok.routing_key, :message_count => basic_get_ok.message_count}

      response = Hash[:header           => header,
                      :payload          => content,
                      :delivery_details => envelope]

      @continuations.push(response)
    end

    def handle_basic_get_empty(basic_get_empty)
      response = {:header => nil, :payload => :queue_empty, :delivery_details => nil}
      @continuations.push(response)
    end

    def handle_frameset(basic_deliver, properties, content)
      consumer = @consumers[basic_deliver.consumer_tag]
      if consumer
        @work_pool.submit do
          consumer.call(MessageMetadata.new(basic_deliver, properties), content)
        end
      end
    end

    def handle_basic_return(basic_return, properties, content)
      x = find_exchange(basic_return.exchange)

      if x
        x.handle_return(basic_return, properties, content)
      else
        # TODO: log a warning
      end
    end

    # Starts consumer work pool. Lazily called by #basic_consume to avoid creating new threads
    # that won't do any real work for channels that do not register consumers (e.g. only used for
    # publishing). MK.
    def maybe_start_consumer_work_pool!
      @work_pool.start unless @work_pool.started?
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

    def find_queue(name)
      @queues[name]
    end

    def register_exchange(exchange)
      @exchanges[exchange.name] = exchange
    end

    def find_exchange(name)
      @exchanges[name]
    end

    protected

    def closed!
      @status = :closed
      @work_pool.shutdown
      @connection.release_channel_id(@id)
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

    def raise_if_no_longer_open!
      raise ChannelAlreadyClosed.new("cannot use a channel that was already closed! Channel id: #{@id}", self) if closed?
    end

    # Unique string supposed to be used as a consumer tag.
    #
    # @return [String]  Unique string.
    # @api plugin
    def generate_consumer_tag(name = "bunny")
      "#{name}-#{Time.now.to_i * 1000}-#{Kernel.rand(999_999_999_999)}"
    end
  end
end
