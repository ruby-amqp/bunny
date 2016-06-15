require "socket"

module Bunny
  # TCP socket extension that uses TCP_NODELAY and supports reading
  # fully.
  #
  # Heavily inspired by Dalli by Mike Perham.
  # @private
  module Socket
    attr_accessor :options

    READ_RETRY_EXCEPTION_CLASSES = [Errno::EAGAIN, Errno::EWOULDBLOCK, IO::WaitReadable]
    WRITE_RETRY_EXCEPTION_CLASSES = [Errno::EAGAIN, Errno::EWOULDBLOCK, IO::WaitWritable]

    def self.open(host, port, options = {})
      @socket_impl = options.fetch(:socket_impl, ::Socket)
      socket = @socket_impl.tcp(host, port, nil, nil,
                            connect_timeout: options[:connect_timeout])
      if @socket_impl.constants.include?('TCP_NODELAY') || @socket_impl.constants.include?(:TCP_NODELAY)
        socket.setsockopt(@socket_impl::IPPROTO_TCP, @socket_impl::TCP_NODELAY, true)
      end
      socket.setsockopt(@socket_impl::SOL_SOCKET, @socket_impl::SO_KEEPALIVE, true) if options.fetch(:keepalive, true)
      socket.extend self
      socket.options = { :host => host, :port => port }.merge(options)
      socket
    rescue Errno::ETIMEDOUT
      raise ClientTimeout
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
      rescue EOFError
        # @eof will break Rubinius' TCPSocket implementation. MK.
        @__bunny_socket_eof_flag__ = true
      rescue *READ_RETRY_EXCEPTION_CLASSES
        if IO.select([self], nil, nil, timeout)
          retry
        else
          raise Timeout::Error, "IO timeout when reading #{count} bytes"
        end
      end
      value
    end # read_fully

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
end
