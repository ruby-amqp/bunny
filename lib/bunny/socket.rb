# frozen_string_literal: true

require "bunny/cruby/socket"

module Bunny
  # An alias for the standard MRI Socket,
  # exists from the days of JRuby support.
  SocketImpl = Socket
end