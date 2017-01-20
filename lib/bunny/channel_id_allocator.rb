require "thread"
require "monitor"
require "amq/int_allocator"

module Bunny
  # Bitset-based channel id allocator. When channels are closed,
  # ids are released back to the pool.
  #
  # Every connection has its own allocator.
  #
  # Allocating and releasing ids is synchronized and can be performed
  # from multiple threads.
  class ChannelIdAllocator

    #
    # API
    #

    # @param [Integer] max_channel Max allowed channel id
    def initialize(max_channel = ((1 << 16) - 1))
      @allocator = AMQ::IntAllocator.new(1, max_channel)
      @mutex     = Monitor.new
    end


    # Returns next available channel id. This method is thread safe.
    #
    # @return [Integer]
    # @api public
    # @see ChannelManager#release_channel_id
    # @see ChannelManager#reset_channel_id_allocator
    def next_channel_id
      @mutex.synchronize do
        @allocator.allocate
      end
    end

    # Releases previously allocated channel id. This method is thread safe.
    #
    # @param [Integer] i Channel id to release
    # @api public
    # @see ChannelManager#next_channel_id
    # @see ChannelManager#reset_channel_id_allocator
    def release_channel_id(i)
      @mutex.synchronize do
        @allocator.release(i)
      end
    end


    # Returns true if given channel id has been previously allocated and not yet released.
    # This method is thread safe.
    #
    # @param [Integer] i Channel id to check
    # @return [Boolean] true if given channel id has been previously allocated and not yet released
    # @api public
    # @see ChannelManager#next_channel_id
    # @see ChannelManager#release_channel_id
    def allocated_channel_id?(i)
      @mutex.synchronize do
        @allocator.allocated?(i)
      end
    end

    # Resets channel allocator. This method is thread safe.
    # @api public
    # @see Channel.next_channel_id
    # @see Channel.release_channel_id
    def reset_channel_id_allocator
      @mutex.synchronize do
        @allocator.reset
      end
    end

    # @private
    def synchronize(&block)
      @mutex.synchronize(&block)
    end
  end
end
