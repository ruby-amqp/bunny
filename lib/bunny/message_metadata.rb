module Bunny
  # Combines message delivery metadata and message metadata behind a single Hash-like
  # immutable data structure that mimics AMQP::Header in amqp gem.
  class MessageMetadata

    #
    # Behaviors
    #

    include Enumerable

    #
    # API
    #

    def initialize(basic_deliver, properties)
      h = {
        :consumer_tag => basic_deliver.consumer_tag,
        :delivery_tag => basic_deliver.delivery_tag,
        :redelivered  => basic_deliver.redelivered,
        :exchange     => basic_deliver.exchange,
        :routing_key  => basic_deliver.routing_key
      }

      @basic_deliver = basic_deliver
      @properties    = properties
      @combined      = properties.merge(h)
    end

    def each(*args, &block)
      @combined.each(*args, &block)
    end

    def [](k)
      @combined[k]
    end

    def to_hash
      @combined
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

    def deliver_tag
      @basic_deliver.deliver_tag
    end

    def redelivered
      @basic_deliver.redelivered
    end

    def exchange
      @basic_deliver.exchange
    end

    def routing_key
      @basic_deliver.routing_key
    end

    def content_type
      @properties[:content_type]
    end

    def content_encoding
      @properties[:content_encoding]
    end

    def headers
      @properties[:headers]
    end

    def delivery_mode
      @properties[:delivery_mode]
    end

    def priority
      @properties[:priority]
    end

    def correlation_id
      @properties[:correlation_id]
    end

    def reply_to
      @properties[:reply_to]
    end

    def expiration
      @properties[:expiration]
    end

    def message_id
      @properties[:message_id]
    end

    def timestamp
      @properties[:timestamp]
    end

    def type
      @properties[:type]
    end

    def user_id
      @properties[:user_id]
    end

    def app_id
      @properties[:app_id]
    end

    def cluster_id
      @properties[:cluster_id]
    end
  end
end
