# -*- coding: utf-8 -*-
# frozen_string_literal: true

module Bunny
  # Passed to [Bunny::TopologyRegistry] to filter entities
  # during topology recovery.
  #
  # @abstract Override to implement the filtering functions.
  #
  # @see Bunny::TopologyRegistry
  class TopologyRecoveryFilter
    # Returns a collection of exchanges that should be recovered during topology recovery.
    # @abstract Override to implement exchange filtering
    # @param xs [Array<Bunny::RecordedExchange>]
    # @return [Array<Bunny::RecordedExchange>]
    def filter_exchanges(xs); raise NotImplementedError; end

    # Returns a collection of queues that should be recovered during topology recovery.
    # @abstract Override to implement queue filtering.
    # @param qs [Array<Bunny::RecordedQueue>]
    # @return [Array<Bunny::RecordedQueue>]
    def filter_queues(qs); raise NotImplementedError; end

    # Returns a collection of exchange bindings that should be recovered during topology recovery.
    # @abstract Override to implement exchange binding filtering
    # @param bs [Set<Bunny::RecordedExchangeBinding>]
    # @return [Array<Bunny::RecordedExchangeBinding>, Set<Bunny::RecordedExchangeBinding>]
    def filter_exchange_bindings(bs); raise NotImplementedError; end

    # Returns a collection of queue bindings that should be recovered during topology recovery.
    # @abstract Override to implement queue binding filtering
    # @param bs [Set<Bunny::RecordedQueueBinding>]
    # @return [Array<Bunny::RecordedQueueBinding>, Set<Bunny::RecordedQueueBinding>]
    def filter_queue_bindings(bs); raise NotImplementedError; end

    # Returns a collection of consumers that should be recovered during topology recovery.
    # @abstract Override to implement consumer filtering
    # @param bs [Array<Bunny::RecordedConsumer>]
    # @return [Array<Bunny::RecordedConsumer>]
    def filter_consumers(bs); raise NotImplementedError; end
  end

  # A no-op topology recovery filter. All methods return
  # their inputs exactly as they are.
  class DefaultTopologyRecoveryFilter < TopologyRecoveryFilter
    # Returns the input without any filtering.
    # @param xs [Array<Bunny::RecordedExchange>]
    # @return [Array<Bunny::RecordedExchange>]
    def filter_exchanges(xs); xs; end

    # Returns the input without any filtering.
    # @param qs [Array<Bunny::RecordedQueue>]
    # @return [Array<Bunny::RecordedQueue>]
    def filter_queues(qs); qs; end

    # Returns the input without any filtering.
    # @param bs [Set<Bunny::RecordedExchangeBinding>]
    # @return [Array<Bunny::RecordedExchangeBinding>, Set<Bunny::RecordedExchangeBinding>]
    def filter_exchange_bindings(bs); bs; end

    # Returns the input without any filtering.
    # @param bs [Set<Bunny::RecordedQueueBinding>]
    # @return [Array<Bunny::RecordedQueueBinding>, Set<Bunny::RecordedQueueBinding>]
    def filter_queue_bindings(bs); bs; end

    # Returns the input without any filtering.
    # @param cs [Array<Bunny::RecordedConsumer>]
    # @return [Array<Bunny::RecordedConsumer>]
    def filter_consumers(cs); cs; end
  end
end