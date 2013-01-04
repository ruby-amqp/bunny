require "thread"
require "set"

require "bunny/consumer_work_pool"

require "bunny/exchange"
require "bunny/queue"

require "bunny/delivery_info"
require "bunny/return_info"
require "bunny/message_properties"

module Bunny
  class Channel

    #
    # API
    #

    attr_accessor :id, :connection, :status, :work_pool
    attr_reader :next_publish_seq_no, :queues, :exchanges


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
      @publishing_mutex = Mutex.new
      @consumer_mutex   = Mutex.new

      @unconfirmed_set_mutex = Mutex.new

      @continuations          = ::Queue.new
      @confirms_continuations = ::Queue.new

      @next_publish_seq_no = 0
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
      self.direct(AMQ::Protocol::EMPTY_STRING, :no_declare => true)
    end

    def exchange(name, opts = {})
      Exchange.new(self, opts.fetch(:type, :direct), name, opts)
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

    def ack(delivery_tag, multiple = false)
      basic_ack(delivery_tag, multiple)
    end
    alias acknowledge ack

    def nack(delivery_tag, requeue, multiple = false)
      basic_nack(delivery_tag, requeue, multiple)
    end

    def on_error(&block)
      @default_error_handler = block
    end

    def using_publisher_confirmations?
      @next_publish_seq_no > 0
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

      if @next_publish_seq_no > 0
        @unconfirmed_set.add(@next_publish_seq_no)
        @next_publish_seq_no += 1
      end

      @connection.send_frameset(AMQ::Protocol::Basic::Publish.encode(@id,
                                                                     payload,
                                                                     meta,
                                                                     exchange_name,
                                                                     routing_key,
                                                                     meta[:mandatory],
                                                                     false,
                                                                     @connection.frame_max), self)

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
      @connection.send_frame(AMQ::Protocol::Basic::Nack.encode(@id,
                                                               delivery_tag,
                                                               requeue,
                                                               multiple))

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

      @connection.send_frame(AMQ::Protocol::Basic::Consume.encode(@id,
                                                                  queue_name,
                                                                  consumer_tag,
                                                                  false,
                                                                  no_ack,
                                                                  exclusive,
                                                                  false,
                                                                  arguments))
      # helps avoid race condition between basic.consume-ok and basic.deliver if there are messages
      # in the queue already. MK.
      if consumer_tag && consumer_tag.strip != AMQ::Protocol::EMPTY_STRING
        add_consumer(queue_name, consumer_tag, no_ack, exclusive, arguments, &block)
      end

      Bunny::Timer.timeout(1, ClientTimeout) do
        @last_basic_consume_ok = @continuations.pop
      end
      # covers server-generated consumer tags
      add_consumer(queue_name, @last_basic_consume_ok.consumer_tag, no_ack, exclusive, arguments, &block)

      @last_basic_consume_ok
    end

    def basic_consume_with(consumer)
      raise_if_no_longer_open!
      maybe_start_consumer_work_pool!

      @connection.send_frame(AMQ::Protocol::Basic::Consume.encode(@id,
                                                                  consumer.queue_name,
                                                                  consumer.consumer_tag,
                                                                  false,
                                                                  consumer.no_ack,
                                                                  consumer.exclusive,
                                                                  false,
                                                                  consumer.arguments))

      # helps avoid race condition between basic.consume-ok and basic.deliver if there are messages
      # in the queue already. MK.
      if consumer.consumer_tag && consumer.consumer_tag.strip != AMQ::Protocol::EMPTY_STRING
        register_consumer(consumer.consumer_tag, consumer)
      end

      Bunny::Timer.timeout(1, ClientTimeout) do
        @last_basic_consume_ok = @continuations.pop
      end
      # covers server-generated consumer tags
      register_consumer(@last_basic_consume_ok.consumer_tag, consumer)

      raise_if_continuation_resulted_in_a_channel_error!

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

      @connection.send_frame(AMQ::Protocol::Queue::Declare.encode(@id,
                                                                  name,
                                                                  opts.fetch(:passive, false),
                                                                  opts.fetch(:durable, false),
                                                                  opts.fetch(:exclusive, false),
                                                                  opts.fetch(:auto_delete, false),
                                                                  false,
                                                                  opts[:arguments]))
      @last_queue_declare_ok = @continuations.pop

      raise_if_continuation_resulted_in_a_channel_error!

      @last_queue_declare_ok
    end

    def queue_delete(name, opts = {})
      raise_if_no_longer_open!

      @connection.send_frame(AMQ::Protocol::Queue::Delete.encode(@id,
                                                                 name,
                                                                 opts[:if_unused],
                                                                 opts[:if_empty],
                                                                 false))
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

      @connection.send_frame(AMQ::Protocol::Queue::Bind.encode(@id,
                                                               name,
                                                               exchange_name,
                                                               opts[:routing_key],
                                                               false,
                                                               opts[:arguments]))
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

      @connection.send_frame(AMQ::Protocol::Queue::Unbind.encode(@id,
                                                                 name,
                                                                 exchange_name,
                                                                 opts[:routing_key],
                                                                 opts[:arguments]))
      Bunny::Timer.timeout(1, ClientTimeout) do
        @last_queue_unbind_ok = @continuations.pop
      end

      raise_if_continuation_resulted_in_a_channel_error!
      @last_queue_unbind_ok
    end


    # exchange.*

    def exchange_declare(name, type, opts = {})
      raise_if_no_longer_open!

      @connection.send_frame(AMQ::Protocol::Exchange::Declare.encode(@id,
                                                                     name,
                                                                     type.to_s,
                                                                     opts.fetch(:passive, false),
                                                                     opts.fetch(:durable, false),
                                                                     opts.fetch(:auto_delete, false),
                                                                     false,
                                                                     false,
                                                                     opts[:arguments]))
      Bunny::Timer.timeout(1, ClientTimeout) do
        @last_exchange_declare_ok = @continuations.pop
      end

      raise_if_continuation_resulted_in_a_channel_error!
      @last_exchange_declare_ok
    end

    def exchange_delete(name, opts = {})
      raise_if_no_longer_open!

      @connection.send_frame(AMQ::Protocol::Exchange::Delete.encode(@id,
                                                                    name,
                                                                    opts[:if_unused],
                                                                    false))
      Bunny::Timer.timeout(1, ClientTimeout) do
        @last_exchange_delete_ok = @continuations.pop
      end

      raise_if_continuation_resulted_in_a_channel_error!
      @last_exchange_delete_ok
    end

    def exchange_bind(source, destination, opts = {})
      raise_if_no_longer_open!

      source_name = if source.respond_to?(:name)
                      source.name
                    else
                      source
                    end

      destination_name = if destination.respond_to?(:name)
                           destination.name
                         else
                           destination
                         end

      @connection.send_frame(AMQ::Protocol::Exchange::Bind.encode(@id,
                                                                  destination_name,
                                                                  source_name,
                                                                  opts[:routing_key],
                                                                  false,
                                                                  opts[:arguments]))
      Bunny::Timer.timeout(1, ClientTimeout) do
        @last_exchange_bind_ok = @continuations.pop
      end

      raise_if_continuation_resulted_in_a_channel_error!
      @last_exchange_bind_ok
    end

    def exchange_unbind(source, destination, opts = {})
      raise_if_no_longer_open!

      source_name = if source.respond_to?(:name)
                      source.name
                    else
                      source
                    end

      destination_name = if destination.respond_to?(:name)
                           destination.name
                         else
                           destination
                         end

      @connection.send_frame(AMQ::Protocol::Exchange::Unbind.encode(@id,
                                                                    destination_name,
                                                                    source_name,
                                                                    opts[:routing_key],
                                                                    false,
                                                                    opts[:arguments]))
      Bunny::Timer.timeout(1, ClientTimeout) do
        @last_exchange_unbind_ok = @continuations.pop
      end

      raise_if_continuation_resulted_in_a_channel_error!
      @last_exchange_unbind_ok
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

    # confirm.*

    def confirm_select
      raise_if_no_longer_open!

      if @next_publish_seq_no == 0
        @confirms_continuations = []
        @unconfirmed_set        = Set.new
        @next_publish_seq_no    = 1
      end

      @connection.send_frame(AMQ::Protocol::Confirm::Select.encode(@id, false))
      Bunny::Timer.timeout(1, ClientTimeout) do
        @last_confirm_select_ok = @continuations.pop
      end
      raise_if_continuation_resulted_in_a_channel_error!
      @last_confirm_select_ok
    end

    def wait_for_confirms
      @only_acks_received = true
      @confirms_continuations.pop

      @only_acks_received
    end


    #
    # Implementation
    #

    def register_consumer(consumer_tag, consumer)
      @consumer_mutex.synchronize do
        @consumers[consumer_tag] = consumer
      end
    end

    def add_consumer(queue, consumer_tag, no_ack, exclusive, arguments, &block)
      @consumer_mutex.synchronize do
        c = Consumer.new(self, queue, consumer_tag, no_ack, exclusive, arguments)
        c.on_delivery(&block) if block
        @consumers[consumer_tag] = c
      end
    end

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
      when AMQ::Protocol::Exchange::BindOk then
        @continuations.push(method)
      when AMQ::Protocol::Exchange::UnbindOk then
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
      when AMQ::Protocol::Basic::Cancel then
        if consumer = @consumers[method.consumer_tag]
          consumer.handle_cancellation(method)
        end

        @consumers.delete(method.consumer_tag)
      when AMQ::Protocol::Basic::CancelOk then
        @continuations.push(method)
        @consumers.delete(method.consumer_tag)
      when AMQ::Protocol::Tx::SelectOk, AMQ::Protocol::Tx::CommitOk, AMQ::Protocol::Tx::RollbackOk then
        @continuations.push(method)
      when AMQ::Protocol::Tx::SelectOk then
        @continuations.push(method)
      when AMQ::Protocol::Confirm::SelectOk then
        @continuations.push(method)
      when AMQ::Protocol::Basic::Ack then
        # TODO: implement confirm listeners
        handle_ack_or_nack(method.delivery_tag, method.multiple, false)
      when AMQ::Protocol::Basic::Nack then
        # TODO: implement confirm listeners
        handle_ack_or_nack(method.delivery_tag, method.multiple, true)
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

    def handle_basic_get_ok(basic_get_ok, properties, content)
      @continuations.push([basic_get_ok, properties, content])
    end

    def handle_basic_get_empty(basic_get_empty)
      @continuations.push([nil, nil, nil])
    end

    def handle_frameset(basic_deliver, properties, content)
      consumer = @consumers[basic_deliver.consumer_tag]
      if consumer
        @work_pool.submit do
          consumer.call(DeliveryInfo.new(basic_deliver), MessageProperties.new(properties), content)
        end
      else
        # TODO: log it
        puts "[warning] No consumer for tag #{basic_deliver.consumer_tag}"
      end
    end

    def handle_basic_return(basic_return, properties, content)
      x = find_exchange(basic_return.exchange)

      if x
        x.handle_return(ReturnInfo.new(basic_return), MessageProperties.new(properties), content)
      else
        # TODO: log a warning
      end
    end

    def handle_ack_or_nack(delivery_tag, multiple, nack)
      if multiple
        @unconfirmed_set.delete_if { |i| i < delivery_tag }
      else
        @unconfirmed_set.delete(delivery_tag)
      end

      @unconfirmed_set_mutex.synchronize do
        @only_acks_received = (@only_acks_received && !nack)

        @confirms_continuations.push(true) if @unconfirmed_set.empty?
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
      @publishing_mutex.synchronize(&block)
    end
    
    def deregister_queue(queue)
      @queues.delete(queue.name)
    end

    def register_queue(queue)
      @queues[queue.name] = queue
    end

    def find_queue(name)
      @queues[name]
    end
    
    def deregister_exchange(exchange)
      @exchanges.delete(exchange.name)
    end

    def register_exchange(exchange)
      @exchanges[exchange.name] = exchange
    end

    def find_exchange(name)
      @exchanges[name]
    end

    # Unique string supposed to be used as a consumer tag.
    #
    # @return [String]  Unique string.
    # @api plugin
    def generate_consumer_tag(name = "bunny")
      "#{name}-#{Time.now.to_i * 1000}-#{Kernel.rand(999_999_999_999)}"
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
  end
end
