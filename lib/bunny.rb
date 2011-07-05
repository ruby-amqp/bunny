# encoding: utf-8

$:.unshift File.expand_path(File.dirname(__FILE__))

# Ruby standard libraries
%w[socket thread timeout logger].each do |file|
  require file
end

require File.expand_path("../bunny/version", __FILE__)

module Bunny

  class ConnectionError < StandardError; end
  class ForcedChannelCloseError < StandardError; end
  class ForcedConnectionCloseError < StandardError; end
  class MessageError < StandardError; end
  class ProtocolError < StandardError; end
  class ServerDownError < StandardError; end
  class UnsubscribeError < StandardError; end
  class AcknowledgementError < StandardError; end

  # Returns the Bunny version number

  def self.version
    VERSION
  end

  # Print deprecation warning.
  def self.deprecation_warning(method, version)
    warn "~ #{method} will be removed in Bunny #{version}."
  end

  # Instantiates new Bunny::Client

  def self.new(opts = {})
    # Set up Bunny according to AMQP spec version required
    spec_version = opts[:spec] || '08'

    # Return client
    setup(spec_version, opts)
  end

  # Runs a code block using a short-lived connection

  def self.run(opts = {}, &block)
    raise ArgumentError, 'Bunny#run requires a block' unless block

    # Set up Bunny according to AMQP spec version required
    spec_version = opts[:spec] || '08'
    client = setup(spec_version, opts)

    begin
      client.start
      block.call(client)
    ensure
      client.stop
    end

    # Return success
    :run_ok
  end

  Timer = if RUBY_VERSION < "1.9"
            begin
              require 'system_timer'
              SystemTimer
            rescue LoadError
              Timeout
            end
          else
            Timeout
          end

  private

  def self.setup(version, opts)
    if version == '08'
      # AMQP 0-8 specification
      require 'qrack/qrack08'
      require 'bunny/client08'
      require 'bunny/exchange08'
      require 'bunny/queue08'
      require 'bunny/channel08'
      require 'bunny/subscription08'

      client = Bunny::Client.new(opts)
    else
      # AMQP 0-9-1 specification
      require 'qrack/qrack09'
      require 'bunny/client09'
      require 'bunny/exchange09'
      require 'bunny/queue09'
      require 'bunny/channel09'
      require 'bunny/subscription09'

      client = Bunny::Client09.new(opts)
    end

    include Qrack

    client
  end

end
