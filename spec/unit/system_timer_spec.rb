require "spec_helper"

if RUBY_VERSION.to_f < 1.9
  describe Bunny::SystemTimer do
    it 'supports being called with a single argument' do
      expect {Bunny::SystemTimer::timeout(1) {}}.not_to raise_error
      expect {Bunny::SystemTimer::timeout(1, nil) {}}.not_to raise_error
    end
  end
end
