require "thread"

module Bunny
  # Network activity loop that reads and passes incoming AMQP 0.9.1 methods for
  # processing. They are dispatched further down the line in Bunny::Session and Bunny::Channel.
  # This loop uses a separate thread internally.
  #
  # This mimics the way RabbitMQ Java is designed quite closely.
  # @private
  class ReaderLoop

    def initialize(transport, session, session_thread)
      @transport      = transport
      @session        = session
      @session_thread = session_thread
      @logger         = @session.logger
    end


    def start
      @thread    = Thread.new(&method(:run_loop))
    end

    def resume
      start
    end


    def run_loop
      loop do
        begin
          break if @stopping || @network_is_down
          run_once
        rescue Errno::EBADF => ebadf
          break if @stopping
          # ignored, happens when we loop after the transport has already been closed
        rescue AMQ::Protocol::EmptyResponseError, IOError, SystemCallError => e
          break if @stopping
          log_exception(e)

          @network_is_down = true

          if @session.automatically_recover?
            @session.handle_network_failure(e)
          else
            @session_thread.raise(Bunny::NetworkFailure.new("detected a network failure: #{e.message}", e))
          end
        rescue ShutdownSignal => _
          break
        rescue Exception => e
          break if @stopping
          log_exception(e)

          @network_is_down = true
          @session_thread.raise(Bunny::NetworkFailure.new("caught an unexpected exception in the network loop: #{e.message}", e))
        end
      end

      @stopped = true
    end

    def run_once
      frame = @transport.read_next_frame
      return if frame.is_a?(AMQ::Protocol::HeartbeatFrame)

      if !frame.final? || frame.method_class.has_content?
        header   = @transport.read_next_frame
        content  = ''

        if header.body_size > 0
          loop do
            body_frame = @transport.read_next_frame
            content << body_frame.decode_payload

            break if content.bytesize >= header.body_size
          end
        end

        @session.handle_frameset(frame.channel, [frame.decode_payload, header.decode_payload, content])
      else
        @session.handle_frame(frame.channel, frame.decode_payload)
      end
    end

    def stop
      @stopping = true
    end

    def stopped?
      @stopped
    end

    def raise(e)
      @thread.raise(e) if @thread
    end

    def join
      @thread.join if @thread
    end

    def kill
      if @thread
        @thread.kill
        @thread.join
      end
    end

    def log_exception(e)
      @logger.error "Exception in the reader loop: #{e.class.name}: #{e.message}"
      @logger.error "Backtrace: "
      e.backtrace.each do |line|
        @logger.error "\t#{line}"
      end
    end
  end
end
