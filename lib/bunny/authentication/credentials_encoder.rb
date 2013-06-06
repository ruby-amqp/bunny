module Bunny
  # Contains credentials encoding implementations for various
  # authentication strategies.
  module Authentication
    # Base credentials encoder. Subclasses implement credentials encoding for
    # a particular authentication mechanism (PLAIN, EXTERNAL, etc).
    #
    # @api plugin
    class CredentialsEncoder

      #
      # API
      #

      # Session that uses this encoder
      # @return [Bunny::Session]
      attr_reader :session

      # Instantiates a new encoder for the authentication mechanism
      # used by the provided session.
      #
      # @return [Bunny::CredentialsEncoder]
      def self.for_session(session)
        registry[session.mechanism].new(session)
      end

      # @private
      def self.registry
        @@registry ||= Hash.new { raise NotImplementedError }
      end

      # Registers an encoder for authentication mechanism
      # @api plugin
      def self.auth_mechanism(*mechanisms)
        mechanisms.each do |m|
          registry[m] = self
        end
      end

      # Encodes provided credentials according to the specific authentication
      # mechanism
      # @return [String] Encoded credentials
      def encode_credentials(username, challenge)
        raise NotImplementedError.new("Subclasses must override this method")
      end

      protected

      def initialize(session)
        @session = session
      end

    end
  end
end
