require_relative '../../../lib/bunny/channel'
require_relative '../../../lib/bunny/session'

module Bunny
  describe Channel do
    it "is an argument error to give a non-zero prefetch count" do
      conn = instance_double(
        Session,
        logger: nil,
        next_channel_id: 1,
        register_channel: nil,
        mutex_impl: Object
      )
      ch = Channel.new(conn)
      expect { ch.basic_qos(-1, global = true) }.
        to raise_error(ArgumentError, "prefetch count must be a positive integer, given: -1")
    end

    it "is an argument error to give a prefetch count beyond MAX_PREFETCH_COUNT" do
      conn = instance_double(
        Session,
        logger: nil,
        next_channel_id: 1,
        register_channel: nil,
        mutex_impl: Object
      )
      ch = Channel.new(conn)
      expect { ch.basic_qos(Channel::MAX_PREFETCH_COUNT + 1, global = true) }.
        to raise_error(
          ArgumentError,
          "prefetch count must be no greater than #{Channel::MAX_PREFETCH_COUNT}, given: #{Channel::MAX_PREFETCH_COUNT + 1}"
        )
    end
  end
end
