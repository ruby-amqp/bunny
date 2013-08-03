# @private
module AMQ
  # @private
  module Protocol
    # @private
    class Basic
      # Extended to allow wrapping delivery tag into
      # a versioned one.
      #
      # @private
      class GetOk
        attr_writer :delivery_tag
      end
    end
  end
end
