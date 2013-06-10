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

    # @private
    def initialize(properties)
      @properties = properties
    end

    # Iterates over the message properties
    # @see Enumerable#each
    def each(*args, &block)
      @properties.each(*args, &block)
    end

    # Accesses message properties by key
    # @see Hash#[]
    def [](k)
      @properties[k]
    end

    # @return [Hash] Hash representation of this delivery info
    def to_hash
      @properties
    end

    # @private
    def to_s
      to_hash.to_s
    end

    # @private
    def inspect
      to_hash.inspect
    end

    # @return [String] (Optional) content type of the message, as set by the publisher
    def content_type
      @properties[:content_type]
    end

    # @return [String] (Optional) content encoding of the message, as set by the publisher
    def content_encoding
      @properties[:content_encoding]
    end

    # @return [String] Message headers
    def headers
      @properties[:headers]
    end

    # @return [Integer] Delivery mode (persistent or transient)
    def delivery_mode
      @properties[:delivery_mode]
    end

    # @return [Integer] Message priority, as set by the publisher
    def priority
      @properties[:priority]
    end

    # @return [String] What message this message is a reply to (or corresponds to), as set by the publisher
    def correlation_id
      @properties[:correlation_id]
    end

    # @return [String] (Optional) How to reply to the publisher (usually a reply queue name)
    def reply_to
      @properties[:reply_to]
    end

    # @return [String] Message expiration, as set by the publisher
    def expiration
      @properties[:expiration]
    end

    # @return [String] Message ID, as set by the publisher
    def message_id
      @properties[:message_id]
    end

    # @return [Time] Message timestamp, as set by the publisher
    def timestamp
      @properties[:timestamp]
    end

    # @return [String] Message type, as set by the publisher
    def type
      @properties[:type]
    end

    # @return [String] Publishing user, as set by the publisher
    def user_id
      @properties[:user_id]
    end

    # @return [String] Publishing application, as set by the publisher
    def app_id
      @properties[:app_id]
    end

    # @return [String] Cluster ID, as set by the publisher
    def cluster_id
      @properties[:cluster_id]
    end
  end
end
