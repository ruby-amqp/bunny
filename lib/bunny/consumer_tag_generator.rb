module Bunny
  # Used to generate consumer tags in the client
  class ConsumerTagGenerator

    #
    # API
    #

    # @return [String] Generated consumer tag
    def generate
      "#{Kernel.rand}-#{Time.now.to_i * 1000}-#{Kernel.rand(999_999_999_999)}"
    end # generate


    # Unique string supposed to be used as a consumer tag.
    #
    # @return [String]  Unique string.
    # @api public
    def generate_prefixed(name = "bunny")
      "#{name}-#{Time.now.to_i * 1000}-#{Kernel.rand(999_999_999_999)}"
    end
  end
end
