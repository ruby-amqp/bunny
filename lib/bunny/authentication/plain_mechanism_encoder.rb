require "bunny/authentication/credentials_encoder"

module Bunny
  module Authentication
    # Encodes credentials using the PLAIN mechanism
    class PlainMechanismEncoder < CredentialsEncoder

      auth_mechanism "PLAIN", "plain"

      # Encodes provided credentials as described in RFC 2595
      # @api public
      # @see http://tools.ietf.org/rfc/rfc2595.txt RFC 2595
      def encode_credentials(username, password)
        "\0#{username}\0#{password}"
      end

    end
  end
end
