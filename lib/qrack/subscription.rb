# encoding: utf-8

#################################################
# WARNING: THIS CLASS IS DEPRECATED, DO NOT     #
# USE IT DIRECTLY! USE BUNNY::CONSUMER INSTEAD! #
#################################################

module Qrack
  # Subscription ancestor class
  # @deprecated
  class Subscription

    attr_accessor :consumer_tag, :delivery_tag, :message_max, :timeout, :ack, :auto_ack, :exclusive
    attr_reader :client, :queue, :message_count

    def initialize(client, queue, opts = {})
      @client = client
      @queue = queue

      # Get timeout value
      @timeout = opts[:timeout] || nil

      # Get maximum amount of messages to process
      @message_max = opts[:message_max] || nil

      # If a consumer tag is not passed in the server will generate one
      @consumer_tag = opts[:consumer_tag] || nil

      # Ignore the :nowait option if passed, otherwise program will hang waiting for a
      # response from the server causing an error.
      opts.delete(:nowait)

      # Do we want to have to provide an acknowledgement?
      @ack = opts[:ack] || nil
      
      # Should the consumer automatically ack messages?
      @auto_ack = opts[:auto_ack].nil? ? @ack : opts[:auto_ack]

      # Does this consumer want exclusive use of the queue?
      @exclusive = opts[:exclusive] || false

      # Initialize message counter
      @message_count = 0

      # Store cancellator
      @cancellator = opts[:cancellator]

      # Store options
      @opts = opts
    end

    def start(&blk)
      # Do not process any messages if zero message_max
      if message_max == 0
        return
      end

      # Notify server about new consumer
      setup_consumer

      # We need to keep track of three possible subscription states
      # :subscribed, :pending, and :unsubscribed
      # 'pending' occurs because of network latency, where we tried to unsubscribe but were already given a message
      subscribe_state = :subscribed

      # Start subscription loop
      loop do

        begin
          method = client.next_method(:timeout => timeout, :cancellator => @cancellator)
        rescue Qrack::FrameTimeout
          begin
            queue.unsubscribe
            subscribe_state = :unsubscribed

            break
          rescue Bunny::ProtocolError
            # Unsubscribe failed because we actually got a message, so we're in a weird state.
            # We have to keep processing the message or else it may be lost...
            # ...and there is also a CancelOk method floating around that we need to consume from the socket

            method = client.last_method
            subscribe_state = :pending
          end
        end

        # Increment message counter
        @message_count += 1

        # get delivery tag to use for acknowledge
        queue.delivery_tag = method.delivery_tag if @ack
        header = client.next_payload

        # The unsubscribe ok may be sprinked into the payload
        if subscribe_state == :pending and header.is_a?(Qrack::Protocol::Basic::CancelOk)
          # We popped off the CancelOk, so we don't have to keep looking for it
          subscribe_state = :unsubscribed

          # Get the actual header now
          header = client.next_payload
        end

        # If maximum frame size is smaller than message payload body then message
        # will have a message header and several message bodies
        msg = ''
        while msg.length < header.size
          message = client.next_payload

          # The unsubscribe ok may be sprinked into the payload
          if subscribe_state == :pending and message.is_a?(Qrack::Protocol::Basic::CancelOk)
            # We popped off the CancelOk, so we don't have to keep looking for it
            subscribe_state = :unsubscribed
            next
          end

          msg << message
        end

        # If block present, pass the message info to the block for processing
        blk.call({:header => header, :payload => msg, :delivery_details => method.arguments}) if !blk.nil?

        # Unsubscribe if we've encountered the maximum number of messages
        if subscribe_state == :subscribed and !message_max.nil? and message_count == message_max
          queue.unsubscribe
          subscribe_state = :unsubscribed
        end

        # Exit the loop if we've unsubscribed
        if subscribe_state != :subscribed
          # We still haven't found the CancelOk, so it's the next method
          if subscribe_state == :pending
            method = client.next_method
            client.check_response(method, Qrack::Protocol::Basic::CancelOk, "Error unsubscribing from queue #{queue.name}, got #{method.class}")

            subscribe_state = :unsubscribed
          end

          # Acknowledge receipt of the final message
          queue.ack() if @auto_ack

          # Quit the loop
          break
        end

        # Have to do the ack here because the ack triggers the release of messages from the server
        # if you are using Client#qos prefetch and you will get extra messages sent through before
        # the unsubscribe takes effect to stop messages being sent to this consumer unless the ack is
        # deferred.
        queue.ack() if @auto_ack
      end
    end

  end

end
