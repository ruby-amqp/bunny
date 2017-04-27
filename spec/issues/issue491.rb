#!/usr/bin/env ruby
# encoding: utf-8

require 'bunny'
require 'open3'

PROXY_PORT = 55672
RABBITMQ_PORT = 5672
BREAKUP_CONNECTION_AFTER = 6
FIX_CONNECTION_AFTER = 12

@toxiproxy_server_thread = nil

# module Bunny
#   class Session
#
#     def send_preamble
#       @transport.write(AMQ::Protocol::PREAMBLE)
#       puts "\nSLEEPING\n"
#
#       @logger.debug "Sent protocol preamble"
#     end
#   end
# end


# Ensure to kill toxiproxy-server
at_exit do
  if @toxiproxy_server_thread
    Process.kill "INT", @toxiproxy_server_thread[:pid]
  end
end

def create_proxy
  system "toxiproxy-cli create bunny_connection_test -l localhost:#{PROXY_PORT} -u localhost:#{RABBITMQ_PORT} >> /dev/null"
  puts 'Proxy created'
end

def start_toxyproxy
  stdin, stdout, @toxiproxy_server_thread = Open3.popen2e 'toxiproxy-server'
  # Test if server has started
  loop do
    break if system 'toxiproxy-cli list >> /dev/null'
  end
  puts 'Toxiproxy server started'
end

def toggle_connection
  system 'toxiproxy-cli toggle bunny_connection_test'
end


# start_toxyproxy
# create_proxy

# Create Bunny client connected to Rabbitmq through our proxy
conn = Bunny.new(
      port: PROXY_PORT,
      user: 'bunny_gem',
      password: 'bunny_password',
      vhost: 'bunny_testbed',
      log_level: :debug,
      recover_from_connection_close: true,
      automatic_recovery: true,
      heartbeat: 10
)
conn.start

ch = conn.create_channel
x  = ch.default_exchange

0.upto(30) do |n|
  x.publish 'Hello, world!', routing_key: 'whatever'
  puts "Published message ##{n}"

  # After a while, abruptly break the connection
  if n == BREAKUP_CONNECTION_AFTER
    puts "n == #{BREAKUP_CONNECTION_AFTER}  => breaking up the connection"
    # toggle_connection  # Break up the connection to Rabbitmq and trigger Bunny's connection recovery
  end

  # Next to connection breakup, after a while, make the broker reachable again
  if n == FIX_CONNECTION_AFTER
    puts "n == #{FIX_CONNECTION_AFTER}  => fixing the connection"
    # toggle_connection  # Re-enable connection to Rabbitmq and make Bunny recovery
  end

  sleep 1
end

