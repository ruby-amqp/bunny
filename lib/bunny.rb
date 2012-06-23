# -*- encoding: utf-8; mode: ruby -*-

require "timeout"

require "bunny/version"
require "amq/protocol/client"

require "bunny/exceptions"

# Core entities: connection, channel, exchange, queue, consumer
require "bunny/session"
require "bunny/channel"
require "bunny/exchange"
require "bunny/queue"
require "bunny/consumer"

module Bunny
  PROTOCOL_VERSION = AMQ::Protocol::PROTOCOL_VERSION

  # unifies Ruby standard library's Timeout (which is not accurate on
  # Ruby 1.8 and has other issues) and SystemTimer (the gem)
  Timer = if RUBY_VERSION < "1.9"
            begin
              require "bunny/system_timer"
              Bunny::SystemTimer
            rescue LoadError
              Timeout
            end
          else
            Timeout
          end


  #
  # API
  #

  def self.version
    VERSION
  end

  def self.protocol_version
    AMQ::Protocol::PROTOCOL_VERSION
  end


  def self.new(connection_string_or_opts = {}, opts = {}, &block)
    if connection_string_or_opts.respond_to?(:keys) && opts.empty?
      opts = connection_string_or_opts
    end

    conn = Session.new(connection_string_or_opts, opts)
    @default_connection ||= conn

    conn
  end


  def self.run(connection_string_or_opts = {}, opts = {}, &block)
    raise ArgumentError, 'Bunny#run requires a block' unless block

    client = Client.new(connection_string_or_opts, opts)

    begin
      client.start
      block.call(client)
    ensure
      client.stop
    end

    :run_ok
  end
end
