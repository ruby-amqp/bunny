module Bunny
  module Authentication
    class CredentialsEncoder

      #
      # API
      #

      attr_reader :session

      def self.for_session(session)
        registry[session.mechanism].new(session)
      end

      def self.registry
        @@registry ||= Hash.new { raise NotImplementedError }
      end

      def self.auth_mechanism(*mechanisms)
        mechanisms.each do |m|
          registry[m] = self
        end
      end

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
