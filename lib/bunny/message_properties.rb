module Bunny
  # Wraps basic properties hash as returned by amq-protocol to
  # provide access to the delivery properties as immutable hash as
  # well as methods.
  class MessageProperties

    #
    # Behaviors
    #

    include Enumerable

    #
    # API
    #

    def initialize(properties)
      @properties = properties
    end

    def each(*args, &block)
      @properties.each(*args, &block)
    end

    def [](k)
      @properties[k]
    end

    def to_hash
      @properties
    end

    def to_s
      to_hash.to_s
    end

    def inspect
      to_hash.inspect
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
