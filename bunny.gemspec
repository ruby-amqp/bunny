#!/usr/bin/env gem build
# encoding: utf-8

require "base64"
require File.expand_path("../lib/bunny/version", __FILE__)

Gem::Specification.new do |s|
  s.name = "bunny"
  s.version = Bunny::VERSION.dup
  s.homepage = "http://github.com/ruby-amqp/bunny"
  s.summary = "Synchronous Ruby AMQP 0.9.1 client"
  s.description = "A synchronous Ruby AMQP 0.9.1 client"

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
  s.add_dependency "amq-protocol", ">= 1.0.0.pre3"

  # Files.
  s.has_rdoc = true
  s.extra_rdoc_files = ["README.textile"]
  s.rdoc_options = ["--main", "README.rdoc"]
  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- spec/*`.split("\n")
  s.require_paths = ["lib"]
end
