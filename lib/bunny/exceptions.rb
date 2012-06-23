module Bunny
  class TCPConnectionFailed < StandardError
    attr_reader :hostname, :port

    def initialize(e, hostname, port)
      super("Could not estabilish TCP connection to #{hostname}:#{port}: #{e.message}")
    end
  end

  class ConnectionClosedError < StandardError
    def initialize(frame)
      if frame.respond_to?(:method_class)
        super("Trying to send frame through a closed connection. Frame is #{frame.inspect}")
      else
        super("Trying to send frame through a closed connection. Frame is #{frame.inspect}, method class is #{frame.method_class}")
      end
    end
  end

  class PossibleAuthenticationFailureError < StandardError

    #
    # API
    #

    def initialize(settings)
      super("AMQP broker closed TCP connection before authentication succeeded: this usually means authentication failure due to misconfiguration or that RabbitMQ version does not support AMQP 0.9.1. Please see http://bit.ly/amqp-gem-080-and-rabbitmq-versions and check your configuration. Settings are #{settings.inspect}.")
    end # initialize(settings)
  end # PossibleAuthenticationFailureError


  # backwards compatibility
  ConnectionError = TCPConnectionFailed
  ServerDownError = TCPConnectionFailed

  # TODO
  class ForcedChannelCloseError < StandardError; end
  class ForcedConnectionCloseError < StandardError; end
  class MessageError < StandardError; end
  class ProtocolError < StandardError; end

  class ConnectionTimeout < Timeout::Error; end
end
