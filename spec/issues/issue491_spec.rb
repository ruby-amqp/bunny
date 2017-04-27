# -*- coding: utf-8 -*-
require 'spec_helper'

include RabbitMQ::Control

describe Bunny::Session do
  let(:logger) { @logz ||= Logger.new STDOUT }

  let(:connection) do
    Bunny.new(
        user: 'bunny_gem', password: 'bunny_password',
        vhost: 'bunny_testbed',
        port: ENV.fetch('RABBITMQ_PORT', 5672),
        log_level: :debug,
        logger: logger
    )
  end

  it 'has a weird behaviour when the broker goes away, then returns but connection cannot complete' do
    # Start RabbitMQ
    Thread.new { RabbitMQ::Control.start_rabbitmq }

    # Ensure Rabbitmq has almost started
    loop do
      break if RabbitMQ::Control.rabbitmq_pid
      sleep 1
    end

    # Give broker some additional time to startup
    logger.debug ' --> Giving RabbiMQ time to startup'
    sleep 5

    # Connect to RabbitMQ
    connection.start
    logger.debug ' ---> Connected to broker'
    channel = connection.create_channel
    def_exchange = channel.default_exchange

    # Redefine Bunny::Session#send_preamble
    $_count = 0
    connection.define_singleton_method(:send_preamble) do
      logger.debug ' --->  Inside redefined :send_preamble'
      @transport.write(AMQ::Protocol::PREAMBLE)
      sleep 6 if $_count == 0  # At least 5 seconds sleep on my machine
      @logger.debug 'Sent protocol preamble'
      $_count += 1
    end

    # Start a thread that publishes 1 message/sec
    t = Thread.new do
      50.times do |n|
        puts "Publishing message ##{n}"
        def_exchange.publish 'Hello, World!', routing_key: 'whatever'
        sleep 1
      end
    end

    # Kill the broker
    logger.debug ' --->  Killing RabbitMQ'
    RabbitMQ::Control.kill_rabbitmq

    # Give it some time to detect connection failure and begin connection recovery ceremony
    sleep 6


    # Restart the broker
    logger.debug ' --->  Starting RabbitMQ'
    RabbitMQ::Control.start_rabbitmq

    # Wait for publishing thread
    t.join
  end
end
