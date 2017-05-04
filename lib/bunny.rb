# -*- encoding: utf-8; mode: ruby -*-

require "timeout"

require "bunny/version"
require "amq/protocol/client"
require "amq/protocol/extensions"

require "bunny/framing"
require "bunny/exceptions"

require "bunny/socket"

require "bunny/timeout"

begin
  require "openssl"

  require "bunny/ssl_socket"
rescue LoadError
  # no-op
end

require "logger"

# Core entities: connection, channel, exchange, queue, consumer
require "bunny/session"
require "bunny/channel"
require "bunny/exchange"
require "bunny/queue"
require "bunny/consumer"

# Bunny is a RabbitMQ client that focuses on ease of use.
# @see http://rubybunny.info
module Bunny
  # AMQP protocol version Bunny implements
  PROTOCOL_VERSION = AMQ::Protocol::PROTOCOL_VERSION

  #
  # API
  #

  # @return [String] Bunny version
  def self.version
    VERSION
  end

  # @return [String] AMQP protocol version Bunny implements
  def self.protocol_version
    AMQ::Protocol::PROTOCOL_VERSION
  end

  # Instantiates a new connection. The actual network
  # connection is started with {Bunny::Session#start}
  #
  # @return [Bunny::Session]
  # @see Bunny::Session#start
  # @see http://rubybunny.info/articles/getting_started.html
  # @see http://rubybunny.info/articles/connecting.html
  # @api public
  def self.new(connection_string_or_opts = ENV['RABBITMQ_URL'], opts = {})
    if connection_string_or_opts.respond_to?(:keys) && opts.empty?
      opts = connection_string_or_opts
    end

    conn = Session.new(connection_string_or_opts, opts)
    @default_connection ||= conn

    conn
  end


  def self.run(connection_string_or_opts = ENV['RABBITMQ_URL'], opts = {}, &block)
    raise ArgumentError, 'Bunny#run requires a block' unless block

    if connection_string_or_opts.respond_to?(:keys) && opts.empty?
      opts = connection_string_or_opts
    end

    client = Session.new(connection_string_or_opts, opts)

    begin
      client.start
      block.call(client)
    ensure
      client.stop
    end

    # backwards compatibility
    :run_ok
  end
end
