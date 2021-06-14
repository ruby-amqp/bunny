# frozen_string_literal: true

require 'spec_helper'

describe 'multiple atribute handling on acks' do
  def measure
    result = {}
    result[:begin] = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield(result)
  rescue => e
    result[:exception] = e
  ensure
    result[:end] = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result[:duration] = (result[:end] - result[:begin]).round(2)
    return result
  end

  before(:all) do
    @connection = Bunny.new(username: 'bunny_gem',
                            password: 'bunny_password',
                            vhost: 'bunny_testbed',
                            automatic_recovery: false,
                            write_timeout: 0,
                            read_timeout: 0)
    @connection.start
  end

  before do
    # Monkey patch with 2 implementations of confirmed subsets + counters for testing
    class Bunny::Channel
      attr_accessor :multiples, :old_implementation

      def handle_ack_or_nack(delivery_tag_before_offset, multiple, nack)
        range_start_testing = old_implementation ? 1 : @unconfirmed_set.min # choose between subsets

        delivery_tag          = delivery_tag_before_offset + @delivery_tag_offset
        confirmed_range_start = multiple ? @delivery_tag_offset + range_start_testing : delivery_tag
        confirmed_range_end   = delivery_tag
        confirmed_range       = (confirmed_range_start..confirmed_range_end)

        # just counting multiples to proof we recieved some
        @multiples = @multiples.to_i + 1 if multiple

        @unconfirmed_set_mutex.synchronize do
          if nack
            @nacked_set.merge(@unconfirmed_set & confirmed_range)
          end

          @unconfirmed_set.subtract(confirmed_range)

          @only_acks_received = (@only_acks_received && !nack)

          @confirms_continuations.push(true) if @unconfirmed_set.empty?

          if @confirms_callback
            confirmed_range.each do |tag|
              @confirms_callback.call(tag, false, nack)
            end
          end
        end
      end
    end
  end

  after(:all) do
    @connection.close if @connection.open?
  end

  let(:messages) { 10_000 }
  let(:channel) { @connection.create_channel }
  let(:queue) { channel.queue('bunny.basic.ack.multiple-acks', auto_delete: true) }

  context 'when multiple atribute used' do
    it 'faster with new implementation' do
      queue.subscribe(manual_ack: false)

      channel.confirm_select

      old = measure do
        channel.old_implementation = true
        exchange = channel.default_exchange

        messages.times do
          exchange.publish('small message', routing_key: queue.name)
        end

        channel.wait_for_confirms

        expect(channel.multiples).to be >= 1
      end
      puts "Old implementation duration: #{old[:duration]} seconds"

      channel.multiples = 0 # clean up

      new = measure do
        channel.old_implementation = false
        exchange = channel.default_exchange

        messages.times do
          exchange.publish('small message', routing_key: queue.name)
        end

        channel.wait_for_confirms

        expect(channel.multiples).to be >= 1
      end
      puts "New implementation duration: #{new[:duration]} seconds"

      expect(new[:duration]).to be < old[:duration]
    end
  end
end
