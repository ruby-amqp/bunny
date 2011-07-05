# encoding: utf-8

module Qrack

  # Queue ancestor class
  class Queue

    attr_reader :name, :client
    attr_accessor :delivery_tag, :subscription


    # Returns consumer count from Queue#status.
    def consumer_count
      s = status
      s[:consumer_count]
    end

    # Returns message count from Queue#status.
    def message_count
      s = status
      s[:message_count]
    end

    # Publishes a message to the queue via the default nameless '' direct exchange.

    # @return [NilClass] nil
    # @deprecated
    # @note This method will be removed before 0.7 release.
    def publish(data, opts = {})
      Bunny.deprecation_warning("Qrack::Queue#publish", "0.7")
      exchange.publish(data, opts)
    end

  end

end
