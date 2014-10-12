#!/usr/bin/env gem build
# encoding: utf-8

require "base64"
require File.expand_path("../lib/bunny/version", __FILE__)

Gem::Specification.new do |s|
  s.name = "bunny"
  s.version = Bunny::VERSION.dup
  s.homepage = "http://rubybunny.info"
  s.summary = "Popular easy to use Ruby client for RabbitMQ"
  s.description = "Easy to use, feature complete Ruby client for RabbitMQ 3.3 and later versions."
  s.license = "MIT"

  # Sorted alphabetically.
  s.authors = [
    "Chris Duncan",
    "Eric Lindvall",
    "Jakub Stastny aka botanicus",
    "Michael S. Klishin",
    "Stefan Kaes"]

  s.email = [
    "Y2VsbGRlZUBnbWFpbC5jb20=\n",
    "ZXJpY0A1c3RvcHMuY29t\n",
    "c3Rhc3RueUAxMDFpZGVhcy5jeg==\n",
    "bWljaGFlbEBub3ZlbWJlcmFpbi5jb20=\n",
    "c2thZXNAcmFpbHNleHByZXNzLmRl\n"].
    map { |mail| Base64.decode64(mail) }

  # Dependencies
  s.add_dependency "amq-protocol", ">= 1.9.2"

  # Files.
  s.has_rdoc = true
  s.extra_rdoc_files = ["README.md"]
  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- spec/*`.split("\n")
  s.require_paths = ["lib"]
end
