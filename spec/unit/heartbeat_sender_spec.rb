require "spec_helper"

describe Bunny::HeartbeatSender do
  let(:transport) { instance_double("Bunny::Transport") }

  # let(:logger) { StringIO.new } # keep test output clear
  let(:logger) { Logger.new(STDOUT) }

  let(:heartbeat_sender) do
    allow(Bunny::Transport).to receive(:new).and_return(transport)
    described_class.new(Bunny::Transport.new, logger)
  end

  it "raises an error when standard error is raised" do
    allow(logger).to receive(:error)
    # This simulates a transport that raises an error.
    allow(heartbeat_sender).to receive(:beat).and_raise(StandardError.new("This error should be logged"))

    heartbeat_sender.start
    expect(logger).to have_received(:error).with("Error in the heartbeat sender: This error should be logged")
  end
end
