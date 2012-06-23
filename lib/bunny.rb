# -*- encoding: utf-8; mode: ruby -*-

require "bunny/version"
require "amq/protocol/client"

module Bunny
  PROTOCOL_VERSION = AMQ::Protocol::PROTOCOL_VERSION


  def self.version
    VERSION
  end

  def self.protocol_version
    AMQ::Protocol::PROTOCOL_VERSION
  end
end
