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

    def reply_code
      @basic_return.reply_code
    end

    def reply_text
      @basic_return.reply_text
    end

    def exchange
      @basic_return.exchange
    end

    def routing_key
      @basic_return.routing_key
    end
  end
end
