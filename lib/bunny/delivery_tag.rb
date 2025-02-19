# frozen_string_literal: true

module Bunny
  # Wraps a delivery tag (which is an integer) so that {Bunny::Channel} does not
  # send stale delivery tags to the new connection after recovery. That is, it
  # pins delivery tag to a connection transport.
  #
  # @private
  class DeliveryTag
    attr_reader :transport

    def initialize(tag, transport)
      raise ArgumentError.new("tag cannot be nil") unless tag
      raise ArgumentError.new("transport cannot be nil") unless transport

      @tag       = tag.to_i
      @transport = transport
    end

    def to_i
      @tag
    end
  end
end
