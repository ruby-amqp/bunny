require "socket"

module Bunny
  begin
    require "openssl"

    # TLS-enabled TCP socket that implements convenience
    # methods found in Bunny::Socket.
    class SSLSocket < OpenSSL::SSL::SSLSocket

    READ_RETRY_EXCEPTION_CLASSES = if defined?(IO::EAGAINWaitReadable)
                                     # Ruby 2.1+
                                     [Errno::EAGAIN, Errno::EWOULDBLOCK, IO::WaitReadable,
                                      IO::EAGAINWaitReadable, IO::EWOULDBLOCKWaitReadable]
                                   else
                                     # 2.0
                                     [Errno::EAGAIN, Errno::EWOULDBLOCK, IO::WaitReadable]
                                   end
    WRITE_RETRY_EXCEPTION_CLASSES = if defined?(IO::EAGAINWaitWritable)
                                      [Errno::EAGAIN, Errno::EWOULDBLOCK, IO::WaitWritable,
                                       IO::EAGAINWaitWritable, IO::EWOULDBLOCKWaitWritable]
                                    else
                                      # 2.0
                                      [Errno::EAGAIN, Errno::EWOULDBLOCK, IO::WaitWritable]
                                    end

      # Reads given number of bytes with an optional timeout
      #
      # @param [Integer] count How many bytes to read
      # @param [Integer] timeout Timeout
      #
      # @return [String] Data read from the socket
      # @api public
      def read_fully(count, timeout = nil)
        return nil if @__bunny_socket_eof_flag__

        value = ''
        begin
          loop do
            value << read_nonblock(count - value.bytesize)
            break if value.bytesize >= count
          end
        rescue EOFError => e
          @__bunny_socket_eof_flag__ = true
        rescue OpenSSL::SSL::SSLError => e
          if e.message == "read would block"
            if IO.select([self], nil, nil, timeout)
              retry
            else
              raise Timeout::Error, "IO timeout when reading #{count} bytes"
            end
          else
            raise e
          end
        rescue *READ_RETRY_EXCEPTION_CLASSES => e
          if IO.select([self], nil, nil, timeout)
            retry
          else
            raise Timeout::Error, "IO timeout when reading #{count} bytes"
          end
        end
        value
      end

      # Writes provided data using IO#write_nonblock, taking care of handling
      # of exceptions it raises when writing would fail (e.g. due to socket buffer
      # being full).
      #
      # IMPORTANT: this method will mutate (slice) the argument. Pass in duplicates
      # if this is not appropriate in your case.
      #
      # @param [String] data Data to write
      # @param [Integer] timeout Timeout
      #
      # @api public
      def write_nonblock_fully(data, timeout = nil)
        return nil if @__bunny_socket_eof_flag__

        length = data.bytesize
        total_count = 0
        count = 0
        loop do
          begin
            count = self.write_nonblock(data)
          rescue OpenSSL::SSL::SSLError => e
            if e.message == "write would block"
              if IO.select([], [self], nil, timeout)
                retry
              else
                raise Timeout::Error, "IO timeout when writing to socket"
              end
            end
            raise e
          rescue *WRITE_RETRY_EXCEPTION_CLASSES
            if IO.select([], [self], nil, timeout)
              retry
            else
              raise Timeout::Error, "IO timeout when writing to socket"
            end
          end

          total_count += count
          return total_count if total_count >= length
          data = data.byteslice(count..-1)
        end

      end

    end
  rescue LoadError => le
    puts "Could not load OpenSSL"
  end
end
