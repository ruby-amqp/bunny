require "bunny/exceptions"

module Bunny
  class CommandAssembler

    #
    # API
    #

    def read_frame(io)
      header = io.read_fully(7)
      type, channel, size = AMQ::Protocol::Frame.decode_header(header)
      payload   = io.read_fully(size)
      frame_end = io.read_fully(1)

      # 1) the size is miscalculated
      if payload.bytesize != size
        raise BadLengthError.new(size, payload.bytesize)
      end

      # 2) the size is OK, but the string doesn't end with FINAL_OCTET
      raise NoFinalOctetError.new if frame_end != AMQ::Protocol::Frame::FINAL_OCTET
      AMQ::Protocol::Frame.new(type, payload, channel)
    end
  end
end
