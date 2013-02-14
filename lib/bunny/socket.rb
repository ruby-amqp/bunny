require "socket"

module Bunny
  # TCP socket extension that uses TCP_NODELAY and supports reading
  # fully.
  #
  # Heavily inspired by Dalli by Mike Perham.
  class Socket < TCPSocket
    attr_accessor :options

    def self.open(host, port, options = {})
      Timeout.timeout(options[:socket_timeout]) do
        sock = new(host, port)
        if Socket.constants.include?('TCP_NODELAY') || Socket.constants.include?(:TCP_NODELAY)
          sock.setsockopt(::Socket::IPPROTO_TCP, ::Socket::TCP_NODELAY, true)
        end
        sock.setsockopt(::Socket::SOL_SOCKET, ::Socket::SO_KEEPALIVE, true) if options[:keepalive]
        sock.options = {:host => host, :port => port}.merge(options)
        sock
      end
    end

    def read_fully(count, timeout = nil)
      return nil if @eof

      value = ''
      begin
        loop do
          value << read_nonblock(count - value.bytesize)
          break if value.bytesize >= count
        end
      rescue EOFError
        @eof = true
      rescue Errno::EAGAIN, Errno::EWOULDBLOCK
        if IO.select([self], nil, nil, timeout)
          retry
        else
          raise Timeout::Error, "IO timeout when reading #{count} bytes"
        end
      end
      value
    end
  end
end
