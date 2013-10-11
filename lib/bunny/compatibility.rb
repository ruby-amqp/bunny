module Bunny
  # Helper methods necessary to stay mostly backwards-compatible with legacy (0.7.x, 0.8.x) Bunny
  # releases that hide channels completely from the API.
  #
  # @private
  module Compatibility

    #
    # API
    #

    # @private
    def channel_from(channel_or_connection)
      # Bunny 0.8.x and earlier completely hide channels from the API. So, queues and exchanges are
      # instantiated with a "Bunny object", which is a session. This function coerces two types of input to a
      # channel.
      if channel_or_connection.is_a?(Bunny::Session)
        channel_or_connection.default_channel
      else
        channel_or_connection
      end
    end
  end
end
