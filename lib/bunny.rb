# -*- encoding: utf-8; mode: ruby -*-

require "timeout"

require "bunny/version"
require "amq/protocol/client"
require "amq/protocol/extensions"

require "bunny/framing"
require "bunny/exceptions"

require "bunny/socket"
require "bunny/timestamp"
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
  # @param [String, Hash] connection_string_or_opts Connection string or a hash of connection options
  # @param [Hash] optz Extra options not related to connection
  #
  # @option connection_string_or_opts [String] :host ("127.0.0.1") Hostname or IP address to connect to
  # @option connection_string_or_opts [Array<String>] :hosts (["127.0.0.1"]) list of hostname or IP addresses to select hostname from when connecting
  # @option connection_string_or_opts [Array<String>] :addresses (["127.0.0.1:5672"]) list of addresses to select hostname and port from when connecting
  # @option connection_string_or_opts [Integer] :port (5672) Port RabbitMQ listens on
  # @option connection_string_or_opts [String] :username ("guest") Username
  # @option connection_string_or_opts [String] :password ("guest") Password
  # @option connection_string_or_opts [String] :vhost ("/") Virtual host to use
  # @option connection_string_or_opts [Integer, Symbol] :heartbeat (:server) Heartbeat timeout to offer to the server. :server means use the value suggested by RabbitMQ. 0 means heartbeats and socket read timeouts will be disabled (not recommended).
  # @option connection_string_or_opts [Integer] :network_recovery_interval (4) Recovery interval periodic network recovery will use. This includes initial pause after network failure.
  # @option connection_string_or_opts [Boolean] :tls (false) Should TLS/SSL be used?
  # @option connection_string_or_opts [String] :tls_cert (nil) Path to client TLS/SSL certificate file (.pem)
  # @option connection_string_or_opts [String] :tls_key (nil) Path to client TLS/SSL private key file (.pem)
  # @option connection_string_or_opts [Array<String>] :tls_ca_certificates Array of paths to TLS/SSL CA files (.pem), by default detected from OpenSSL configuration
  # @option connection_string_or_opts [String] :verify_peer (true) Whether TLS peer verification should be performed
  # @option connection_string_or_opts [Symbol] :tls_protocol (negotiated) What TLS version should be used (:TLSv1, :TLSv1_1, or :TLSv1_2)
  # @option connection_string_or_opts [Integer] :channel_max (2047) Maximum number of channels allowed on this connection, minus 1 to account for the special channel 0.
  # @option connection_string_or_opts [Integer] :continuation_timeout (15000) Timeout for client operations that expect a response (e.g. {Bunny::Queue#get}), in milliseconds.
  # @option connection_string_or_opts [Integer] :connection_timeout (30) Timeout in seconds for connecting to the server.
  # @option connection_string_or_opts [Integer] :read_timeout (30) TCP socket read timeout in seconds. If heartbeats are disabled this will be ignored.
  # @option connection_string_or_opts [Integer] :write_timeout (30) TCP socket write timeout in seconds.
  # @option connection_string_or_opts [Proc] :hosts_shuffle_strategy a callable that reorders a list of host strings, defaults to Array#shuffle
  # @option connection_string_or_opts [Proc] :recovery_completed a callable that will be called when a network recovery is performed
  # @option connection_string_or_opts [Logger] :logger The logger.  If missing, one is created using :log_file and :log_level.
  # @option connection_string_or_opts [IO, String] :log_file The file or path to use when creating a logger.  Defaults to STDOUT.
  # @option connection_string_or_opts [IO, String] :logfile DEPRECATED: use :log_file instead.  The file or path to use when creating a logger.  Defaults to STDOUT.
  # @option connection_string_or_opts [Integer] :log_level The log level to use when creating a logger.  Defaults to LOGGER::WARN
  # @option connection_string_or_opts [Boolean] :automatically_recover (true) Should automatically recover from network failures?
  # @option connection_string_or_opts [Integer] :recovery_attempts (nil) Max number of recovery attempts, nil means forever
  # @option connection_string_or_opts [Integer] :reset_recovery_attempts_after_reconnection (true) Should recovery attempt counter be reset after successful reconnection? When set to false, the attempt counter will last through the entire lifetime of the connection object.
  # @option connection_string_or_opts [Proc] :recovery_attempt_started (nil) Will be called before every connection recovery attempt
  # @option connection_string_or_opts [Proc] :recovery_completed (nil) Will be called after successful connection recovery
  # @option connection_string_or_opts [Boolean] :recover_from_connection_close (true) Should this connection recover after receiving a server-sent connection.close (e.g. connection was force closed)?
  # @option connection_string_or_opts [Object] :session_error_handler (Thread.current) Object which responds to #raise that will act as a session error handler. Defaults to Thread.current, which will raise asynchronous exceptions in the thread that created the session.
  #
  # @option optz [String] :auth_mechanism ("PLAIN") Authentication mechanism, PLAIN or EXTERNAL
  # @option optz [String] :locale ("PLAIN") Locale RabbitMQ should use
  # @option optz [String] :connection_name (nil) Client-provided connection name, if any. Note that the value returned does not uniquely identify a connection and cannot be used as a connection identifier in HTTP API requests.
  #
  # @return [Bunny::Session]
  # @see Bunny::Session#start
  # @see http://rubybunny.info/articles/getting_started.html
  # @see http://rubybunny.info/articles/connecting.html
  # @api public
  def self.new(connection_string_or_opts = ENV['RABBITMQ_URL'], optz = {})
    if connection_string_or_opts.respond_to?(:keys) && optz.empty?
      optz = connection_string_or_opts
    end

    conn = Session.new(connection_string_or_opts, optz)
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
