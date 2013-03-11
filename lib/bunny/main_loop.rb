require "thread"

module Bunny
  # Network activity loop that reads and passes incoming AMQP 0.9.1 methods for
  # processing. They are dispatched further down the line in Bunny::Session and Bunny::Channel.
  # This loop uses a separate thread internally.
  #
  # This mimics the way RabbitMQ Java is designed quite closely.
  class MainLoop

    def initialize(transport, session)
      @transport = transport
      @session   = session
    end


    def start
      @thread    = Thread.new(&method(:run_loop))
      @thread.abort_on_exception = true
    end

    def resume
      start
    end


    def run_loop
      loop do
        begin
          break if @stopping || @network_is_down
          run_once
        rescue Timeout::Error => te
          # given that the server may be pushing data to us, timeout detection/handling
          # should happen per operation and not in this loop
        rescue Errno::EBADF => ebadf
          # ignored, happens when we loop after the transport has already been closed
        rescue AMQ::Protocol::EmptyResponseError, IOError, Errno::EPIPE, Errno::EAGAIN, Errno::ECONNRESET => e
          puts "Exception in the main loop: #{e.class.name}"
          @network_is_down = true
          @session.handle_network_failure(e)
        rescue Exception => e
          puts e.class.name
          puts e.message
          puts e.backtrace
        end
      end
    end

    def run_once
      frame = @transport.read_next_frame
      @session.signal_activity!

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

    def kill
      @thread.kill
      @thread.join
    end
  end
end
