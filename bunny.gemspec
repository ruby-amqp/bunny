#!/usr/bin/env gem build
# encoding: utf-8

require File.expand_path("../lib/bunny/version", __FILE__)

Gem::Specification.new do |s|
  s.name = "bunny"
  s.version = Bunny::VERSION.dup
  s.homepage = "http://rubybunny.info"
  s.summary = "Popular easy to use Ruby client for RabbitMQ"
  s.description = "Easy to use, feature complete Ruby client for RabbitMQ 3.9 and later versions."
  s.license = "MIT"
  s.required_ruby_version = Gem::Requirement.new(">= 2.5")

  s.metadata = {
    "changelog_uri" => "https://github.com/ruby-amqp/bunny/blob/main/ChangeLog.md",
    "source_code_uri" => "https://github.com/ruby-amqp/bunny/",
  }

  # Sorted alphabetically.
  s.authors = [
    "Chris Duncan",
    "Eric Lindvall",
    "Jakub Stastny aka botanicus",
    "Michael S. Klishin",
    "Stefan Kaes"]

  s.email = ["michael.s.klishin@gmail.com"]

  # Dependencies
  s.add_runtime_dependency 'amq-protocol', '~> 2.3'
  s.add_runtime_dependency 'logger', '~> 1', '>= 1.7'
  s.add_runtime_dependency 'sorted_set', '~> 1', '>= 1.0.2'

  # Files.
  s.extra_rdoc_files = ["README.md"]
  s.files         = `git ls-files -- lib/*`.split("\n").reject { |f| f.match(%r{^bin/ci/}) }
  s.require_paths = ["lib"]
end
