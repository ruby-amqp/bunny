# -*- encoding: utf-8; mode: ruby -*-

$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)

require 'bundler'
Bundler.setup(:default, :test)


require "effin_utf8"
require "bunny"
require "rabbitmq/http/client"


require "amq/protocol/version"
puts "Using Ruby #{RUBY_VERSION}, amq-protocol #{AMQ::Protocol::VERSION}"



#
# Ruby version-specific
#

case RUBY_VERSION
when "1.8.7" then
  class Array
    alias sample choice
  end
when "1.8.6" then
  raise "Ruby 1.8.6 is not supported. Sorry, pal. Time to move on beyond One True Ruby. Yes, time flies by."
end



module RabbitMQ
  module Control
    def rabbitmq_pid
      $1.to_i if `rabbitmqctl status` =~ /\{pid,(\d+)\}/
    end

    def start_rabbitmq(delay = 1.0)
      # this is Homebrew-specific :(
      `rabbitmq-server > /dev/null 2>&1 &`; sleep(delay)
    end

    def stop_rabbitmq(pid = rabbitmq_pid, delay = 1.0)
      `rabbitmqctl stop`; sleep(delay)
    end

    def kill_rabbitmq(pid = rabbitmq_pid, delay = 1.0)
      # tango is down, tango is down!
      Process.kill("KILL", pid); sleep(delay)
    end
  end
end


module PlatformDetection
  def mri?
    !defined?(RUBY_ENGINE) || (defined?(RUBY_ENGINE) && ("ruby" == RUBY_ENGINE))
  end

  def rubinius?
    defined?(RUBY_ENGINE) && (RUBY_ENGINE == 'rbx')
  end
end
