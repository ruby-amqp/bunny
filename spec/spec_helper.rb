require "bunny"

# Support both old and new rspec syntax.
RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = [:should, :expect]
  end
end
