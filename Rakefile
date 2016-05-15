require 'rake'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:integration) do |t|
  # excludes unit tests as those involve many iterations
  # and sometimes suffer from obscure interference from integration tests (!)
  t.pattern    = ["spec/higher_level_api/integration", "spec/lower_level_api/integration", "spec/issues", "spec/stress"].
    map { |dir| Dir.glob(File.join(dir, "**", "*_spec.rb")) }.reduce(&:+) - ["spec/higher_level_api/integration/tls_connection_spec.rb"]

  t.rspec_opts = "--format progress"
end

RSpec::Core::RakeTask.new(:unit) do |t|
  t.pattern    = Dir.glob("spec/unit/**/*_spec.rb")

  t.rspec_opts = "--format progress --backtrace"
end

RSpec::Core::RakeTask.new(:recovery_integration) do |t|
  # otherwise all examples will be skipped
  ENV.delete("CI")
  t.pattern    = Dir.glob("spec/higher_level_api/integration/connection_recovery_spec.rb")

  t.rspec_opts = "--format progress --backtrace"
end

task :default => :integration
