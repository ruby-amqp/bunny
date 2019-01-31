require 'rake'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:integration) do |t|
  # excludes unit tests as those involve many iterations
  # and sometimes suffer from obscure interference from integration tests (!)
  t.pattern    = ["spec/higher_level_api/integration", "spec/lower_level_api/integration", "spec/issues"].
    map { |dir| Dir.glob(File.join(dir, "**", "*_spec.rb")) }.reduce(&:+) - ["spec/higher_level_api/integration/tls_connection_spec.rb"]

  t.rspec_opts = "--format progress"
end

RSpec::Core::RakeTask.new(:integration_without_recovery) do |t|
  # same as :integration but excludes client connection recovery tests.
  # useful for sanity checking edge RabbitMQ builds, for instance.
  t.pattern    = ["spec/higher_level_api/integration", "spec/lower_level_api/integration", "spec/issues"].
    map { |dir| Dir.glob(File.join(dir, "**", "*_spec.rb")) }.reduce(&:+) -
    ["spec/higher_level_api/integration/tls_connection_spec.rb",
     "spec/higher_level_api/integration/connection_recovery_spec.rb"]

  t.rspec_opts = "--format progress"
end

RSpec::Core::RakeTask.new(:unit) do |t|
  t.pattern    = Dir.glob("spec/unit/**/*_spec.rb")

  t.rspec_opts = "--format progress --backtrace"
end

RSpec::Core::RakeTask.new(:recovery_integration) do |t|
  # otherwise all examples will be skipped
  ENV.delete("CI")
  t.pattern    = ["spec/higher_level_api/integration/connection_recovery_spec.rb"]

  t.rspec_opts = "--format progress --backtrace"
end

RSpec::Core::RakeTask.new(:stress) do |t|
  # excludes unit tests as those involve many iterations
  # and sometimes suffer from obscure interference from integration tests (!)
  t.pattern    = ["spec/stress/**/*_spec.rb"]

  t.rspec_opts = "--format progress"
end

task :default => :integration

namespace :tls do
  desc "Checks the certificates and keys in BUNNY_CERTIFICATE_DIR with openssl s_client"
  task :s_client do
    dir = ENV["BUNNY_CERTIFICATE_DIR"]
    sh "openssl s_client -tls1_2 -connect 127.0.0.1:5671 -cert #{dir}/client_certificate.pem -key #{dir}/client_key.pem -CAfile #{dir}/ca_certificate.pem"
  end
end
