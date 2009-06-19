$: << File.expand_path(File.dirname(__FILE__))

require 'protocol/spec091'
require 'protocol/protocol'

require 'transport/buffer'
require 'transport/frame091'

require 'qrack/client'

module Qrack
	
	include Protocol
	include Transport
	
	# Errors
	class BufferOverflowError < StandardError; end
  class InvalidTypeError < StandardError; end

  # Qrack version number
  VERSION = '0.0.1'

  # Return the Qrack version
  def self.version
    VERSION
  end

end