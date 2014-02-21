module Bunny
  # Base class that represents consumer interface. Subclasses of this class implement
  # specific logic of handling consumer life cycle events. Note that when the only event
  # you are interested in is message deliveries, it is recommended to just use
  # {Bunny::Queue#subscribe} instead of subclassing this class.
  #
  # @see Bunny::Queue#subscribe
  # @see Bunny::Queue#subscribe_with
  # @see http://rubybunny.info/articles/queues.html Queues and Consumers guide
  # @api public
  class Consumer

    #
    # API
    #

    attr_reader   :channel
    attr_reader   :queue
    attr_accessor :consumer_tag
    attr_reader   :arguments
    attr_reader   :no_ack
    attr_reader   :exclusive


    # @param [Bunny::Channel] channel Channel this consumer will use
    # @param [Bunny::Queue,String] queue Queue messages will be consumed from
    # @param [String] consumer_tag Consumer tag (unique identifier). Generally it is better to let Bunny generate one.
    #                              Empty string means RabbitMQ will generate consumer tag.
    # @param [Boolean] no_ack (true) If true, delivered messages will be automatically acknowledged.
    #                                 If false, manual acknowledgements will be necessary.
    # @param [Boolean] exclusive (false) Should this consumer be exclusive?
    # @param [Hash] arguments (nil) Optional arguments that may be used by RabbitMQ extensions, etc
    # @api public
    def initialize(channel, queue, consumer_tag = channel.generate_consumer_tag, no_ack = true, exclusive = false, arguments = {})
      @channel       = channel || raise(ArgumentError, "channel is nil")
      @queue         = queue   || raise(ArgumentError, "queue is nil")
      @consumer_tag  = consumer_tag
      @exclusive     = exclusive
      @arguments     = arguments
      # no_ack set to true = no manual ack = automatic ack. MK.
      @no_ack        = no_ack

      @on_cancellation = []
    end

    # Defines message delivery handler
    # @api public
    def on_delivery(&block)
      @on_delivery = block
      self
    end

    # Invokes message delivery handler
    # @private
    def call(*args)
      @on_delivery.call(*args) if @on_delivery
    end
    alias handle_delivery call

    # Defines consumer cancellation notification handler
    #
    # @see http://rubybunny.info/articles/queues.html Queues and Consumers guide
    # @see http://rubybunny.info/articles/extensions.html RabbitMQ Extensions guide
    # @api public
    def on_cancellation(&block)
      @on_cancellation << block
      self
    end

    # Invokes consumer cancellation notification handler
    # @private
    def handle_cancellation(basic_cancel)
      @on_cancellation.each do |fn|
        fn.call(basic_cancel)
      end
    end

    # Cancels this consumer. Messages for this consumer will no longer be delivered. If the queue
    # it was on is auto-deleted and this consumer was the last one, the queue will be deleted.
    #
    # @see http://rubybunny.info/articles/queues.html Queues and Consumers guide
    # @api public
    def cancel
      @channel.basic_cancel(@consumer_tag)
    end

    # @return [String] More detailed human-readable string representation of this consumer
    def inspect
      "#<#{self.class.name}:#{object_id} @channel_id=#{@channel.number} @queue=#{self.queue_name}> @consumer_tag=#{@consumer_tag} @exclusive=#{@exclusive} @no_ack=#{@no_ack}>"
    end

    # @return [String] Brief human-readable string representation of this consumer
    def to_s
      "#<#{self.class.name}:#{object_id} @channel_id=#{@channel.number} @queue=#{self.queue_name}> @consumer_tag=#{@consumer_tag}>"
    end

    # @return [Boolean] true if this consumer uses automatic acknowledgement mode
    # @api public
    def automatic_acknowledgement?
      @no_ack == true
    end

    # @return [Boolean] true if this consumer uses manual (explicit) acknowledgement mode
    # @api public
    def manual_acknowledgement?
      @no_ack == false
    end

    # @return [String] Name of the queue this consumer is on
    # @api public
    def queue_name
      if @queue.respond_to?(:name)
        @queue.name
      else
        @queue
      end
    end

    #
    # Recovery
    #

    # @private
    def recover_from_network_failure
      @channel.basic_consume_with(self)
    end
  end
end
