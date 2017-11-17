require "bunny/cruby/socket"

module Bunny
  module JRuby
    # TCP socket extension that uses Socket#readpartial to avoid excessive CPU
    # burn after some time. See issue #165.
    # @private
    module Socket
      include Bunny::Socket

      def self.open(host, port, options = {})
        socket = ::Socket.tcp(host, port, nil, nil,
                              connect_timeout: options[:connect_timeout])
        if ::Socket.constants.include?('TCP_NODELAY') || ::Socket.constants.include?(:TCP_NODELAY)
          socket.setsockopt(::Socket::IPPROTO_TCP, ::Socket::TCP_NODELAY, true)
        end
        socket.setsockopt(::Socket::SOL_SOCKET, ::Socket::SO_KEEPALIVE, true) if options.fetch(:keepalive, true)
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
        value = ''

        begin
          loop do
            value << read_nonblock(count - value.bytesize)
            break if value.bytesize >= count
          end
        rescue EOFError
          # JRuby specific fix via https://github.com/jruby/jruby/issues/1694#issuecomment-54873532
          IO.select([self], nil, nil, timeout)
          retry
        rescue *READ_RETRY_EXCEPTION_CLASSES
          if IO.select([self], nil, nil, timeout)
            retry
          else
            raise Timeout::Error, "IO timeout when reading #{count} bytes"
          end
        end

        value
      end # read_fully

    end
  end
end
