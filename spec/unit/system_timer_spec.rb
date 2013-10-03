require "spec_helper"

if RUBY_VERSION.to_f < 1.9
  describe Bunny::SystemTimer do
    it 'supports being called with a single argument' do
      lambda {Bunny::SystemTimer::timeout(1) {}}.should_not raise_error
      lambda {Bunny::SystemTimer::timeout(1, nil) {}}.should_not raise_error
    end
  end
end
