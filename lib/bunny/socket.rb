# See #165. MK.
if defined?(JRUBY_VERSION)
  require "bunny/jruby/socket"

  module Bunny
    SocketImpl = JRuby::Socket
  end
else
  require "bunny/cruby/socket"

  module Bunny
    SocketImpl = Socket
  end
end
