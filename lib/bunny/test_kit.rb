# -*- coding: utf-8 -*-

require "timeout"

module Bunny
  # Unit, integration and stress testing toolkit
  class TestKit
    class << self

      def poll_while(timeout = 60, &probe)
        Timeout.timeout(timeout) {
          sleep 0.1 while probe.call
        }
      end
      def poll_until(timeout = 60, &probe)
        Timeout.timeout(timeout) {
          sleep 0.1 until probe.call
        }
      end

      # @return [Integer] Random integer in the range of [a, b]
      # @api private
      def random_in_range(a, b)
        Range.new(a, b).to_a.sample
      end

      # @param  [Integer] a Lower bound of message size, in KB
      # @param  [Integer] b Upper bound of message size, in KB
      # @param  [Integer] i Random number to use in message generation
      # @return [String] Message payload of length in the given range, with non-ASCII characters
      # @api public
      def message_in_kb(a, b, i)
        s = "Ю#{i}"
        n = random_in_range(a, b) / s.bytesize

        s * n * 1024
      end

    end
  end
end
