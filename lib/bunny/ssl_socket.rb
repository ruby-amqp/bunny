# See #165. MK.
if defined?(JRUBY_VERSION)
  require "bunny/jruby/ssl_socket"

  module Bunny
    SSLSocketImpl = JRuby::SSLSocket
  end
else
  require "bunny/cruby/ssl_socket"

  module Bunny
    SSLSocketImpl = SSLSocket
  end
end
