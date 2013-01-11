module Bunny
  class Consumer

    #
    # API
    #

    attr_reader   :channel
    attr_reader   :queue
    attr_accessor :consumer_tag
    attr_reader   :arguments
    attr_reader   :no_ack
    attr_reader   :exclusive



    def initialize(channel, queue, consumer_tag = channel.generate_consumer_tag, no_ack = true, exclusive = false, arguments = {})
      @channel       = channel || raise(ArgumentError, "channel is nil")
      @queue         = queue   || raise(ArgumentError, "queue is nil")
      @consumer_tag  = consumer_tag
      @exclusive     = exclusive
      @arguments     = arguments
      @no_ack        = no_ack
    end


    def on_delivery(&block)
      @on_delivery = block
      self
    end

    def call(*args)
      @on_delivery.call(*args) if @on_delivery
    end
    alias handle_delivery call

    def on_cancellation(&block)
      @on_cancellation = block
      self
    end

    def handle_cancellation(basic_cancel)
      @on_cancellation.call(basic_cancel) if @on_cancellation
    end

    def queue_name
      if @queue.respond_to?(:name)
        @queue.name
      else
        @queue
      end
    end

    def cancel
      @channel.basic_cancel(@consumer_tag)
    end

    def inspect
      "#<#{self.class.name}:#{object_id} @channel_id=#{@channel.number} @queue=#{self.queue_name}> @consumer_tag=#{@consumer_tag} @exclusive=#{@exclusive} @no_ack=#{@no_ack}>"
    end

    #
    # Recovery
    #

    def recover_from_network_failure
      # TODO
    end
  end
end
