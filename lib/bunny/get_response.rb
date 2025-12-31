# frozen_string_literal: true

module Bunny
  # Wraps {AMQ::Protocol::Basic::GetOk} to
  # provide access to the delivery properties as immutable hash as
  # well as methods. Hash representation is created lazily.
  class GetResponse

    #
    # Behaviors
    #

    include Enumerable

    #
    # API
    #

    # @return [Bunny::Channel] Channel this basic.get-ok response is on
    attr_reader :channel

    # @private
    def initialize(get_ok, channel)
      @get_ok  = get_ok
      @channel = channel
    end

    # Iterates over the delivery properties
    # @see Enumerable#each
    def each(*args, &block)
      to_hash.each(*args, &block)
    end

    # Accesses delivery properties by key
    # @see Hash#[]
    def [](k)
      case k
      when :delivery_tag then @get_ok.delivery_tag
      when :redelivered  then @get_ok.redelivered
      when :exchange     then @get_ok.exchange
      when :routing_key  then @get_ok.routing_key
      when :channel      then @channel
      else nil
      end
    end

    # @return [Hash] Hash representation of this delivery info
    def to_hash
      @hash ||= {
        :delivery_tag => @get_ok.delivery_tag,
        :redelivered  => @get_ok.redelivered,
        :exchange     => @get_ok.exchange,
        :routing_key  => @get_ok.routing_key,
        :channel      => @channel
      }
    end

    # @private
    def to_s
      to_hash.to_s
    end

    # @private
    def inspect
      to_hash.inspect
    end

    # @return [String] Delivery identifier that is used to acknowledge, reject and nack deliveries
    def delivery_tag
      @get_ok.delivery_tag
    end

    # @return [Boolean] true if this delivery is a redelivery (the message was requeued at least once)
    def redelivered
      @get_ok.redelivered
    end
    alias redelivered? redelivered

    # @return [String] Name of the exchange this message was published to
    def exchange
      @get_ok.exchange
    end

    # @return [String] Routing key this message was published with
    def routing_key
      @get_ok.routing_key
    end
  end
end
