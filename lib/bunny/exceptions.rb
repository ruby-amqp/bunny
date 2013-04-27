module Bunny
  class Exception < ::StandardError
  end

  class NetworkFailure < Exception
    attr_reader :cause

    def initialize(message, cause)
      super(message)
      @cause = cause
    end
  end

  class ChannelLevelException < Exception
    attr_reader :channel, :channel_close

    def initialize(message, ch, channel_close)
      super(message)

      @channel       = ch
      @channel_close = channel_close
    end
  end

  class ConnectionLevelException < Exception
    attr_reader :connection, :connection_close

    def initialize(message, connection, connection_close)
      super(message)

      @connection       = connection
      @connection_close = connection_close
    end
  end


  class TCPConnectionFailed < Exception
    attr_reader :hostname, :port

    def initialize(e, hostname, port)
      m = case e
          when String then
            e
          when Exception then
            e.message
          end
      super("Could not estabilish TCP connection to #{hostname}:#{port}: #{m}")
    end
  end

  class ConnectionClosedError < Exception
    def initialize(frame)
      if frame.respond_to?(:method_class)
        super("Trying to send frame through a closed connection. Frame is #{frame.inspect}, method class is #{frame.method_class}")
      else
        super("Trying to send frame through a closed connection. Frame is #{frame.inspect}")
      end
    end
  end

  class PossibleAuthenticationFailureError < Exception

    #
    # API
    #

    attr_reader :username, :vhost

    def initialize(username, vhost, password_length)
      @username = username
      @vhost    = vhost

      super("AMQP broker closed TCP connection before authentication succeeded: this usually means authentication failure due to misconfiguration or that RabbitMQ version does not support AMQP 0.9.1. Please check your configuration. Username: #{username}, vhost: #{vhost}, password length: #{password_length}")
    end # initialize(settings)
  end # PossibleAuthenticationFailureError


  # backwards compatibility
  ConnectionError = TCPConnectionFailed
  ServerDownError = TCPConnectionFailed

  class ForcedChannelCloseError < Exception; end
  class ForcedConnectionCloseError < Exception; end
  class MessageError < Exception; end
  class ProtocolError < Exception; end

  # raised when read or write I/O operations time out (but only if
  # a connection is configured to use them)
  class ClientTimeout     < Timeout::Error; end
  # raised on initial connection timeout
  class ConnectionTimeout < Timeout::Error; end


  # Base exception class for data consistency and framing errors.
  class InconsistentDataError < Exception
  end

  # Raised by adapters when frame does not end with {final octet AMQ::Protocol::Frame::FINAL_OCTET}.
  # This suggest that there is a bug in adapter or AMQ broker implementation.
  #
  # @see http://files.travis-ci.org/docs/amqp/0.9.1/AMQP091Specification.pdf AMQP 0.9.1 specification (Section 2.3)
  class NoFinalOctetError < InconsistentDataError
    def initialize
      super("Frame doesn't end with #{AMQ::Protocol::Frame::FINAL_OCTET} as it must, which means the size is miscalculated.")
    end
  end

  # Raised by adapters when actual frame payload size in bytes is not equal
  # to the size specified in that frame's header.
  # This suggest that there is a bug in adapter or AMQ broker implementation.
  #
  # @see http://files.travis-ci.org/docs/amqp/0.9.1/AMQP091Specification.pdf AMQP 0.9.1 specification (Section 2.3)
  class BadLengthError < InconsistentDataError
    def initialize(expected_length, actual_length)
      super("Frame payload should be #{expected_length} long, but it's #{actual_length} long.")
    end
  end


  class ChannelAlreadyClosed < Exception
    attr_reader :channel

    def initialize(message, ch)
      super(message)

      @channel = ch
    end
  end

  class PreconditionFailed < ChannelLevelException
  end

  class NotFound < ChannelLevelException
  end

  class ResourceLocked < ChannelLevelException
  end

  class AccessRefused < ChannelLevelException
  end


  class ChannelError < ConnectionLevelException
  end

  class InvalidCommand < ConnectionLevelException
  end

  class UnexpectedFrame < ConnectionLevelException
  end

  class NetworkErrorWrapper < Exception
    attr_reader :other

    def initialize(other)
      super(other.message)
      @other = other
    end
  end

  class ConnectionForced < ConnectionLevelException
  end

end
