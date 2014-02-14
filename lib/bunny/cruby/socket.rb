require "socket"

module Bunny
  # TCP socket extension that uses TCP_NODELAY and supports reading
  # fully.
  #
  # Heavily inspired by Dalli by Mike Perham.
  # @private
  class Socket < TCPSocket
    attr_accessor :options

    # IO::WaitReadable is 1.9+ only
    READ_RETRY_EXCEPTION_CLASSES = [Errno::EAGAIN, Errno::EWOULDBLOCK]
    READ_RETRY_EXCEPTION_CLASSES << IO::WaitReadable if IO.const_defined?(:WaitReadable)

    def self.open(host, port, options = {})
      Timeout.timeout(options[:socket_timeout], ClientTimeout) do
        sock = new(host, port)
        if ::Socket.constants.include?('TCP_NODELAY') || ::Socket.constants.include?(:TCP_NODELAY)
          sock.setsockopt(::Socket::IPPROTO_TCP, ::Socket::TCP_NODELAY, true)
        end
        sock.setsockopt(::Socket::SOL_SOCKET, ::Socket::SO_KEEPALIVE, true) if options.fetch(:keepalive, true)
        sock.options = {:host => host, :port => port}.merge(options)
        sock
      end
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
    #
    # @api public
    def write_nonblock_fully(data)
      return nil if @__bunny_socket_eof_flag__

      begin
        while !data.empty?
          written = self.write_nonblock(data)
          data.slice!(0, written)
        end
      rescue Errno::EWOULDBLOCK, Errno::EAGAIN
        IO.select([], [self])
        retry
      end

      data.bytesize
    end
  end
end
