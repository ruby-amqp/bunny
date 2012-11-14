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
    end

    def run_loop
      loop do
        Thread.exit if @stopped

        begin
          frame = @transport.read_next_frame

          @session.signal_activity!

          if frame.is_a?(AMQ::Protocol::HeartbeatFrame)
            return
          end

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

            @session.handle_frameset(frame.channel, [frame.decode_payload, header, content])            
          else
            @session.handle_frame(frame.channel, frame.decode_payload)
          end
        rescue Timeout::Error => te
          # TODO: rework the way we read data, add actual timeout detection/handling
        rescue Errno::EBADF => ebadf
          # ignored, happens when we loop after the transport has already been closed
        rescue Exception => e
          puts e.class.name
          puts e.message
          puts e.backtrace
        end
      end
    end

    def stop
      @stopped = true
    end
  end
end
