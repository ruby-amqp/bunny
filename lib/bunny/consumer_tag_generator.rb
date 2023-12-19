module Bunny
  # Used to generate consumer tags in the client
  class ConsumerTagGenerator

    #
    # API
    #

    # @return [String] Generated consumer tag
    def generate
      t = Bunny::Timestamp.now
      "#{Kernel.rand}-#{t.to_i * 1000}-#{Kernel.rand(999_999_999_999)}"
    end # generate


    # Unique string supposed to be used as a consumer tag.
    #
    # @return [String]  Unique string.
    # @api public
    def generate_prefixed(name = "bunny")
      t = Bunny::Timestamp.now
      "#{name}-#{t.to_i * 1000}-#{Kernel.rand(999_999_999_999)}"
    end
  end
end
