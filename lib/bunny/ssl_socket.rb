# frozen_string_literal: true

require "bunny/cruby/ssl_socket"

module Bunny
  # An alias for the standard SSLSocket,
  # exists from the days of JRuby support.
  SSLSocketImpl = SSLSocket
end