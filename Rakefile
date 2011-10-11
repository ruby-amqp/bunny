# encoding: utf-8

require "bundler/gem_tasks"

desc "Run rspec tests"
task :spec do
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new("spec") do |t|
    t.pattern = "spec/spec_*/*_spec.rb"
    t.rspec_opts = ['--color', '--format doc']
  end
end

task :default => [ :spec ]
