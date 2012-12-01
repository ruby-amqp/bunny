require "thread"
require "amq/int_allocator"

module Bunny
  class ChannelIdAllocator

    #
    # API
    #

    def initialize(max_channel = ((1 << 16) - 1))
      @int_allocator ||= AMQ::IntAllocator.new(1, max_channel)

      @channel_id_mutex ||= Mutex.new
    end


    # Returns next available channel id. This method is thread safe.
    #
    # @return [Fixnum]
    # @api public
    # @see ChannelManager#release_channel_id
    # @see ChannelManager#reset_channel_id_allocator
    def next_channel_id
      @channel_id_mutex.synchronize do
        @int_allocator.allocate
      end
    end

    # Releases previously allocated channel id. This method is thread safe.
    #
    # @param [Fixnum] Channel id to release
    # @api public
    # @see ChannelManager#next_channel_id
    # @see ChannelManager#reset_channel_id_allocator
    def release_channel_id(i)
      @channel_id_mutex.synchronize do
        @int_allocator.release(i)
      end
    end # self.release_channel_id(i)


    def allocated_channel_id?(i)
      @channel_id_mutex.synchronize do
        @int_allocator.allocated?(i)
      end
    end

    # Resets channel allocator. This method is thread safe.
    # @api public
    # @see Channel.next_channel_id
    # @see Channel.release_channel_id
    def reset_channel_id_allocator
      @channel_id_mutex.synchronize do
        @int_allocator.reset
      end
    end # reset_channel_id_allocator
  end
end
