module Transport

  class Frame #:nodoc: all
    def initialize payload = nil, channel = 0
      @channel, @payload = channel, payload
    end
    attr_accessor :channel, :payload

    def id
      self.class::ID
    end
    
    def to_binary
      buf = Transport::Buffer.new
      buf.write :octet, id
      buf.write :short, channel
      buf.write :longstr, payload
      buf.write :octet, Transport::Frame::FOOTER
      buf.rewind
      buf
    end

    def to_s
      to_binary.to_s
    end

    def == frame
      [ :id, :channel, :payload ].inject(true) do |eql, field|
        eql and __send__(field) == frame.__send__(field)
      end
    end
    
    class Method
      def initialize payload = nil, channel = 0
        super
        unless @payload.is_a? Protocol::Class::Method or @payload.nil?
          @payload = Protocol.parse(@payload)
        end
      end
    end

    class Header
      def initialize payload = nil, channel = 0
        super
        unless @payload.is_a? Protocol::Header or @payload.nil?
          @payload = Protocol::Header.new(@payload)
        end
      end
    end

    class Body; end

    def self.parse buf
      buf = Transport::Buffer.new(buf) unless buf.is_a? Transport::Buffer
      buf.extract do
        id, channel, payload, footer = buf.read(:octet, :short, :longstr, :octet)
        Transport::Frame.types[id].new(payload, channel) if footer == Transport::Frame::FOOTER
      end
    end
  end
end