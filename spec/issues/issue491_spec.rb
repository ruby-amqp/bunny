require 'spec_helper'

include RabbitMQ::Control

describe Bunny::Session do
  let(:logger) { @lgr ||= Logger.new STDOUT }

  let(:connection) do
    Bunny.new(
        user: 'bunny_gem', password: 'bunny_password',
        vhost: 'bunny_testbed',
        port: ENV.fetch('RABBITMQ_PORT', 5672),
        log_level: :debug,
        logger: logger
    )
  end

  context 'after connection recovery is triggered' do
    def start_rabbitmq
      # Start RabbitMQ
      Thread.new { RabbitMQ::Control.start_rabbitmq }

      # Ensure Rabbitmq has almost started
      loop do
        sleep 1
        break if RabbitMQ::Control.rabbitmq_pid
      end

      # Give broker some additional time to startup
      sleep 5
    end


    describe '#recover_from_network_failure' do
      before :each do
        start_rabbitmq
        connection.start
      end

      after :each do
        start_rabbitmq
      end

      it 'should try to recover after a SystemCallError exception is raised during a reconnection attempt' do

        # Redefine Session#send_preamble so that it triggers a SystemCallError
        connection.define_singleton_method(:send_preamble) do
          @transport.write(AMQ::Protocol::PREAMBLE)
          @logger.debug 'Sent protocol preamble redefined'
          raise SystemCallError
        end

        # Kill the broker
        RabbitMQ::Control.kill_rabbitmq

        expect(connection).to receive(:announce_network_failure_recovery)

        sleep 6
      end
    end
  end
end
