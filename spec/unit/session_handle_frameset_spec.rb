# -*- coding: utf-8 -*-
# frozen_string_literal: true
require "spec_helper"

describe Bunny::Session do
  # A frameset (e.g. basic.deliver + headers + body) can arrive for a channel
  # that was already closed and unregistered; this must not crash the reader loop.

  let(:logger) { Logger.new(IO::NULL) }

  def new_session(opts = {})
    Bunny.new({
      host: "127.0.0.1",
      port: 65_534,
      logger: logger
    }.merge(opts))
  end

  describe "#handle_frameset" do
    it "logs a warning and does not raise when the channel is not registered" do
      session = new_session

      expect(logger).to receive(:warn).with(/Channel 42 is not open on this connection!/)
      expect do
        session.handle_frameset(42, [AMQ::Protocol::Basic::GetEmpty.new(nil)])
      end.not_to raise_error
    end
  end
end
