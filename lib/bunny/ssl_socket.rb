require "socket"

module Bunny
  begin
    require "openssl"

    class SSLSocket < OpenSSL::SSL::SSLSocket
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
        rescue Errno::EAGAIN, Errno::EWOULDBLOCK, OpenSSL::SSL::SSLError => e
          puts e.inspect
          if IO.select([self], nil, nil, timeout)
            retry
          else
            raise Timeout::Error, "IO timeout when reading #{count} bytes"
          end
        end
        value
      end
    end
  rescue LoadError => le
    puts "Could not load OpenSSL"
  end
end
