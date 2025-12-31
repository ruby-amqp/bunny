# frozen_string_literal: true

require "thread"

module Bunny
  module Concurrent
    # A thread-safe exception accumulator that stores exceptions for later retrieval
    # instead of immediately raising them in the calling thread.
    #
    # This is the default session error handler in Bunny. When errors occur in
    # background threads (such as the reader loop or transport), they are stored
    # in the accumulator rather than being raised asynchronously in the thread
    # that created the session.
    #
    # This prevents dangerous control flow interruptions that can occur when
    # exceptions are raised asynchronously via Thread#raise.
    #
    # @example Checking for accumulated exceptions
    #   conn = Bunny.new
    #   conn.start
    #   # ... do work ...
    #   if conn.exception_occurred?
    #     exceptions = conn.exceptions
    #     # handle exceptions appropriately
    #   end
    #
    # @see https://github.com/ruby-amqp/bunny/issues/721
    # @api public
    class ExceptionAccumulator
      def initialize
        @exceptions = []
        @mutex = Mutex.new
      end

      # Called by background threads to record an exception.
      # This method is compatible with Thread#raise interface.
      #
      # @param exception [Exception] the exception to accumulate
      def raise(exception)
        @mutex.synchronize do
          @exceptions << exception
        end
      end

      # Returns true if any exceptions have been accumulated.
      #
      # @return [Boolean]
      def any?
        @mutex.synchronize { @exceptions.any? }
      end

      # Returns true if no exceptions have been accumulated.
      #
      # @return [Boolean]
      def empty?
        @mutex.synchronize { @exceptions.empty? }
      end

      # Returns the number of accumulated exceptions.
      #
      # @return [Integer]
      def count
        @mutex.synchronize { @exceptions.count }
      end

      # Returns all accumulated exceptions.
      #
      # @return [Array<Exception>]
      def all
        @mutex.synchronize { @exceptions.dup }
      end

      # Returns and removes the first accumulated exception (FIFO order).
      # Returns nil if no exceptions have been accumulated.
      #
      # @return [Exception, nil]
      def pop
        @mutex.synchronize { @exceptions.shift }
      end

      # Clears all accumulated exceptions.
      #
      # @return [Array<Exception>] the exceptions that were cleared
      def clear
        @mutex.synchronize do
          cleared = @exceptions.dup
          @exceptions.clear
          cleared
        end
      end

      # Raises the first accumulated exception if any exist, removing it from the accumulator.
      # Does nothing if no exceptions have been accumulated.
      #
      # @raise [Exception] the first accumulated exception
      def raise_first!
        exception = pop
        Kernel.raise exception if exception
      end

      # Raises all accumulated exceptions wrapped in a single exception if any exist,
      # clearing the accumulator.
      #
      # @raise [Bunny::AccumulatedExceptions] wrapper containing all accumulated exceptions
      def raise_all!
        exceptions = clear
        return if exceptions.empty?
        Kernel.raise AccumulatedExceptions.new(exceptions)
      end
    end
  end

  # Alias for backward compatibility and convenience
  ExceptionAccumulator = Concurrent::ExceptionAccumulator
end
