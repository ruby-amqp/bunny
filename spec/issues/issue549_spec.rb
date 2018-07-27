require 'spec_helper'

describe Bunny::Session do
  context 'when retry attempts have been exhausted' do
    let(:io) { StringIO.new } # keep test output clear

    def create_session
      described_class.new(
        host: 'fake.host',
        recovery_attempts: 0,
        connection_timeout: 0,
        network_recovery_interval: 0,
        logfile: io,
      )
    end

    it 'closes the session' do
      session = create_session
      session.handle_network_failure(StandardError.new)
      expect(session.closed?).to be true
    end

    it 'stops the reader loop' do
      session = create_session
      reader_loop = session.reader_loop
      session.handle_network_failure(StandardError.new)
      expect(reader_loop.stopping?).to be true
    end
  end
end
