# -*- coding: utf-8 -*-
# frozen_string_literal: true
require "spec_helper"

describe Bunny::Session do
  # These examples exercise the connection recovery orchestration logic
  # in isolation, without a running RabbitMQ node: connection-level
  # operations are stubbed out. End-to-end recovery behavior is covered
  # by the integration specs.

  let(:logger) { Logger.new(IO::NULL) }

  def new_session(opts = {})
    Bunny.new({
      host: "127.0.0.1",
      port: 65_534,
      network_recovery_interval: 0,
      logger: logger
    }.merge(opts))
  end

  describe "#handle_network_failure" do
    it "runs a single recovery when failures are reported concurrently" do
      session = new_session

      recovery_started  = Queue.new
      release_recovery  = Queue.new

      allow(session).to receive(:recover_connection_and_channels) do
        recovery_started.push(true)
        release_recovery.pop
        true
      end
      allow(session).to receive(:recover_topology)
      allow(session).to receive(:notify_of_recovery_completion)
      allow(session).to receive(:open?).and_return(true)

      first = Thread.new { session.handle_network_failure(IOError.new("first")) }
      recovery_started.pop

      # a second failure signal arrives while a recovery is in progress,
      # e.g. from a publishing thread that ran into a write error
      second = Thread.new { session.handle_network_failure(IOError.new("second")) }
      second.join
      expect(session.recovering_from_network_failure?).to be true

      release_recovery.push(true)
      first.join

      expect(session.recovering_from_network_failure?).to be false
      expect(session).to have_received(:recover_connection_and_channels).once
    end

    it "runs another full recovery round when the connection is lost again mid-recovery" do
      session = new_session

      rounds = 0
      allow(session).to receive(:recover_connection_and_channels) { rounds += 1; true }
      allow(session).to receive(:recover_topology)
      allow(session).to receive(:notify_of_recovery_completion)
      # the connection is gone again by the time topology recovery finished,
      # e.g. the node was drained one more time before shutting down
      allow(session).to receive(:open?).and_return(false, true)

      session.handle_network_failure(IOError.new("node is being drained"))

      expect(rounds).to eq 2
      expect(session).to have_received(:notify_of_recovery_completion).once
    end

    it "gives up mid-recovery rounds when recovery attempts are exhausted" do
      exhausted = false
      session = new_session(recovery_attempts: 1,
                            recovery_attempts_exhausted: -> { exhausted = true },
                            reset_recovery_attempts_after_reconnection: false)

      allow(session).to receive(:recover_connection_and_channels).and_return(true)
      allow(session).to receive(:recover_topology)
      allow(session).to receive(:notify_of_recovery_completion)
      allow(session).to receive(:open?).and_return(false)
      allow(session).to receive(:close)

      session.handle_network_failure(IOError.new("node is gone"))

      expect(exhausted).to be true
      expect(session).not_to have_received(:notify_of_recovery_completion)
      expect(session.recovering_from_network_failure?).to be false
    end

    it "releases the recovery guard when a recovery round raises" do
      session = new_session

      allow(session).to receive(:recover_connection_and_channels).and_raise(RuntimeError, "unexpected")

      expect do
        session.handle_network_failure(IOError.new("failure"))
      end.to raise_error(RuntimeError, "unexpected")

      expect(session.recovering_from_network_failure?).to be false
    end

    it "does not attempt recovery for exceptions that are not recoverable" do
      session = new_session
      session.recoverable_exceptions = [IOError]

      allow(session).to receive(:recover_connection_and_channels)

      session.handle_network_failure(SignalException.new("TERM"))

      expect(session).not_to have_received(:recover_connection_and_channels)
      expect(session.recovering_from_network_failure?).to be false
    end
  end

  describe "#recover_connection_and_channels" do
    it "treats a connection that did not reach the open state as a failed attempt" do
      exhausted = false
      session = new_session(recovery_attempts: 1,
                            recovery_attempts_exhausted: -> { exhausted = true },
                            reset_recovery_attempts_after_reconnection: false)

      allow(session).to receive(:initialize_transport)
      allow(session).to receive(:start)
      allow(session).to receive(:open?).and_return(false)
      allow(session).to receive(:close)
      allow(session).to receive(:recover_channels)

      expect(session.send(:recover_connection_and_channels)).to be false
      expect(exhausted).to be true
      expect(session).not_to have_received(:recover_channels)
    end

    it "returns true and recovers channels when the connection is open again" do
      session = new_session

      allow(session).to receive(:initialize_transport)
      allow(session).to receive(:start)
      allow(session).to receive(:open?).and_return(true)
      allow(session).to receive(:recover_channels)

      expect(session.send(:recover_connection_and_channels)).to be true
      expect(session).to have_received(:recover_channels)
    end
  end

  describe "#recover_topology" do
    it "attempts to recover the remaining consumers when one of them fails" do
      session = new_session
      channel = double("channel")

      session.record_consumer_with(channel, "tag-1", "q-1", proc {}, true, false, {})
      session.record_consumer_with(channel, "tag-2", "q-2", proc {}, true, false, {})

      recovered = []
      allow(session).to receive(:recover_consumer) do |rc|
        recovered << rc.consumer_tag
        raise "boom" if rc.consumer_tag == "tag-1"
      end

      expect { session.send(:recover_topology) }.not_to raise_error
      expect(recovered.sort).to eq %w[tag-1 tag-2]
    end
  end
end
