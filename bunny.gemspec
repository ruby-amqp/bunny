#!/usr/bin/env gem build
# encoding: utf-8

require "base64"
require File.expand_path("../lib/bunny/version", __FILE__)

Gem::Specification.new do |s|
  s.name = "bunny"
  s.version = Bunny::VERSION.dup
  s.homepage = "http://rubybunny.info"
  s.summary = "Easy to use Ruby client for RabbitMQ"
  s.description = "Easy to use, feature complete Ruby client for RabbitMQ"
  s.license = "MIT"
  s.required_ruby_version = Gem::Requirement.new(">= 2.2")

  # Sorted alphabetically.
  s.authors = [
    "Chris Duncan",
    "Eric Lindvall",
    "Jakub Stastny aka botanicus",
    "Michael S. Klishin",
    "Stefan Kaes"]

  s.email = ["mklishin@pivotal.io"]

  # Dependencies
  s.add_runtime_dependency 'amq-protocol', '~> 2.3', '>= 2.3.0'

  # Files.
  s.extra_rdoc_files = ["README.md"]
  s.files         = `git ls-files`.split("\n").reject { |f| f.match(%r{^bin/ci/}) }
  s.test_files    = `git ls-files -- spec/*`.split("\n")
  s.require_paths = ["lib"]
end
