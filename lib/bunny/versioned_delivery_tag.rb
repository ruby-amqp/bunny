module Bunny
  # Wraps a delivery tag (which is an integer) so that {Bunny::Channel} could
  # detect stale tags after connection recovery.
  #
  # @private
  class VersionedDeliveryTag
    attr_reader :tag
    attr_reader :version

    def initialize(tag, version)
      raise ArgumentError.new("tag cannot be nil") unless tag
      raise ArgumentError.new("version cannot be nil") unless version

      @tag     = tag.to_i
      @version = version.to_i
    end

    def to_i
      @tag
    end

    def stale?(version)
      raise ArgumentError.new("version cannot be nil") unless version

      @version < version.to_i
    end
  end
end
