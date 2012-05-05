# encoding: utf-8

require "socket"
require "thread"
require "timeout"
require "logger"

require File.expand_path("../bunny/version", __FILE__)
# if we don't require the version file the same way as in the gemspec,
# the version file will be loaded twice. and we hate warnings.

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
  def self.deprecation_warning(method, version, explanation)
    warn "~ #{method} will be removed in Bunny #{version}. #{explanation}"
  end

  # Instantiates new Bunny::Client

  def self.new(connection_string_or_opts = Hash.new, opts = Hash.new)
    # Set up Bunny
    if connection_string_or_opts.respond_to?(:keys) && opts.empty?
      opts = connection_string_or_opts
    end

    # Return client
    setup(connection_string_or_opts, opts)
  end

  # Runs a code block using a Bunny connection
  def self.run(connection_string_or_opts = {}, opts = {}, &block)
    raise ArgumentError, 'Bunny#run requires a block' unless block

    # Set up Bunny
    client = setup(connection_string_or_opts, opts)

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
              require File.expand_path(File.join(File.dirname(__FILE__), 'system_timer.rb'))
              Bunny::SystemTimer
            rescue LoadError
              Timeout
            end
          else
            Timeout
          end

  private

  def self.setup(*args)
    # AMQP 0-9-1 specification
    require 'qrack/qrack'
    require 'bunny/client'
    require 'bunny/exchange'
    require 'bunny/queue'
    require 'bunny/channel'
    require 'bunny/subscription'

    include Qrack

    client = Bunny::Client.new(*args)
  end

end
