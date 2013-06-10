module Bunny
  # @private
  module Framing
    ENCODINGS_SUPPORTED = defined? Encoding
    HEADER_SLICE = (0..6).freeze
    DATA_SLICE = (7..-1).freeze
    PAYLOAD_SLICE = (0..-2).freeze

    # @private
    module String
      class Frame < AMQ::Protocol::Frame
        def self.decode(string)
          header              = string[HEADER_SLICE]
          type, channel, size = self.decode_header(header)
          data                = string[DATA_SLICE]
          payload             = data[PAYLOAD_SLICE]
          frame_end           = data[-1, 1]

          frame_end.force_encoding(AMQ::Protocol::Frame::FINAL_OCTET.encoding) if ENCODINGS_SUPPORTED

          # 1) the size is miscalculated
          if payload.bytesize != size
            raise BadLengthError.new(size, payload.bytesize)
          end

          # 2) the size is OK, but the string doesn't end with FINAL_OCTET
          raise NoFinalOctetError.new if frame_end != AMQ::Protocol::Frame::FINAL_OCTET

          self.new(type, payload, channel)
        end
      end
    end # String


    # @private
    module IO
      class Frame < AMQ::Protocol::Frame
        def self.decode(io)
          header = io.read(7)
          type, channel, size = self.decode_header(header)
          data = io.read_fully(size + 1)
          payload, frame_end = data[PAYLOAD_SLICE], data[-1, 1]

          # 1) the size is miscalculated
          if payload.bytesize != size
            raise BadLengthError.new(size, payload.bytesize)
          end

          # 2) the size is OK, but the string doesn't end with FINAL_OCTET
          raise NoFinalOctetError.new if frame_end != AMQ::Protocol::Frame::FINAL_OCTET
          self.new(type, payload, channel)
        end # self.from
      end # Frame
    end # IO
  end # Framing
end # Bunny
