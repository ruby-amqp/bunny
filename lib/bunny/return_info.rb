module Bunny
  # Wraps AMQ::Protocol::Basic::Return to
  # provide access to the delivery properties as immutable hash as
  # well as methods.
  class ReturnInfo

    #
    # Behaviors
    #

    include Enumerable

    #
    # API
    #

    def initialize(basic_return)
      @basic_return = basic_return
      @hash          = {
        :reply_code   => basic_return.reply_code,
        :reply_text   => basic_return.reply_text,
        :exchange     => basic_return.exchange,
        :routing_key  => basic_return.routing_key
      }
    end

    # Iterates over the returned delivery properties
    # @see Enumerable#each
    def each(*args, &block)
      @hash.each(*args, &block)
    end

    # Accesses returned delivery properties by key
    # @see Hash#[]
    def [](k)
      @hash[k]
    end

    # @return [Hash] Hash representation of this returned delivery info
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

    # @return [Integer] Reply (status) code of the cause
    def reply_code
      @basic_return.reply_code
    end

    # @return [Integer] Reply (status) text of the cause, explaining why the message was returned
    def reply_text
      @basic_return.reply_text
    end

    # @return [String] Exchange the message was published to
    def exchange
      @basic_return.exchange
    end

    # @return [String] Routing key the message has
    def routing_key
      @basic_return.routing_key
    end
  end
end
