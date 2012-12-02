module Bunny
  # Wraps AMQ::Protocol::Basic::Deliver to
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

    def initialize(basic_deliver)
      @basic_deliver = basic_deliver
      @hash          = {
        :consumer_tag => basic_deliver.consumer_tag,
        :delivery_tag => basic_deliver.delivery_tag,
        :redelivered  => basic_deliver.redelivered,
        :exchange     => basic_deliver.exchange,
        :routing_key  => basic_deliver.routing_key
      }
    end

    def each(*args, &block)
      @hash.each(*args, &block)
    end

    def [](k)
      @hash[k]
    end

    def to_hash
      @hash
    end

    def to_s
      to_hash.to_s
    end

    def inspect
      to_hash.inspect
    end

    def consumer_tag
      @basic_deliver.consumer_tag
    end

    def delivery_tag
      @basic_deliver.delivery_tag
    end

    def redelivered
      @basic_deliver.redelivered
    end
    alias redelivered? redelivered

    def exchange
      @basic_deliver.exchange
    end

    def routing_key
      @basic_deliver.routing_key
    end
  end
end
