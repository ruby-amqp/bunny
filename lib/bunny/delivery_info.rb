require "bunny/versioned_delivery_tag"

module Bunny
  # Wraps {AMQ::Protocol::Basic::Deliver} to
  # provide access to the delivery properties as immutable hash as
  # well as methods.
  class DeliveryInfo

    #
    # Behaviors
    #

    include Enumerable

    #
    # API
    #

    # @return [Bunny::Consumer] Consumer this delivery is for
    attr_reader :consumer
    # @return [Bunny::Channel] Channel this delivery is on
    attr_reader :channel

    # @private
    def initialize(basic_deliver, consumer, channel)
      @basic_deliver = basic_deliver
      @hash          = {
        :consumer_tag => basic_deliver.consumer_tag,
        :delivery_tag => VersionedDeliveryTag.new(basic_deliver.delivery_tag, channel.recoveries_counter),
        :redelivered  => basic_deliver.redelivered,
        :exchange     => basic_deliver.exchange,
        :routing_key  => basic_deliver.routing_key,
        :consumer     => consumer,
        :channel      => channel
      }
      @consumer      = consumer
      @channel       = channel
    end

    # Iterates over the delivery properties
    # @see Enumerable#each
    def each(*args, &block)
      @hash.each(*args, &block)
    end

    # Accesses delivery properties by key
    # @see Hash#[]
    def [](k)
      @hash[k]
    end

    # @return [Hash] Hash representation of this delivery info
    def to_hash
      @hash
    end

    # @private
    def to_s
      to_hash.to_s
    end

    # @private
    def inspect
      to_hash.inspect
    end

    # @return [String] Consumer tag this delivery is for
    def consumer_tag
      @basic_deliver.consumer_tag
    end

    # @return [String] Delivery identifier that is used to acknowledge, reject and nack deliveries
    def delivery_tag
      @basic_deliver.delivery_tag
    end

    # @return [Boolean] true if this delivery is a redelivery (the message was requeued at least once)
    def redelivered
      @basic_deliver.redelivered
    end
    alias redelivered? redelivered

    # @return [String] Name of the exchange this message was published to
    def exchange
      @basic_deliver.exchange
    end

    # @return [String] Routing key this message was published with
    def routing_key
      @basic_deliver.routing_key
    end
  end
end
