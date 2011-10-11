# encoding: utf-8

require "bundler/gem_tasks"

desc "Run AMQP rspec tests"
task :spec do
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new("spec") do |t|
    t.pattern = "spec/spec_09/*_spec.rb"
    t.rspec_opts = ['--color']
  end
end

task :default => [ :spec ]
