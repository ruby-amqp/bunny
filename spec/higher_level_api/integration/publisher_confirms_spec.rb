require "spec_helper"

describe Bunny::Channel do
  after :each do
    connection.close if connection.open?
  end

  let(:n) { 200 }

  shared_examples "publish confirms" do
    context "when publishing with confirms enabled" do
      it "increments delivery index" do
        ch = connection.create_channel
        expect(ch).not_to be_using_publisher_confirmations

        ch.confirm_select
        expect(ch).to be_using_publisher_confirmations

        q  = ch.queue("", exclusive: true)
        x  = ch.default_exchange

        n.times do
          x.publish("xyzzy", routing_key: q.name)
        end

        expect(ch.next_publish_seq_no).to eq n + 1
        expect(ch.wait_for_confirms).to eq true
        sleep 0.25

        expect(q.message_count).to eq n
        q.purge

        ch.close
      end

      describe "#wait_for_confirms" do
        it "should not hang when all the publishes are confirmed" do
          ch = connection.create_channel
          expect(ch).not_to be_using_publisher_confirmations

          ch.confirm_select
          expect(ch).to be_using_publisher_confirmations

          q  = ch.queue("", exclusive: true)
          x  = ch.default_exchange

          n.times do
            x.publish("xyzzy", routing_key: q.name)
          end

          expect(ch.next_publish_seq_no).to eq n + 1
          expect(ch.wait_for_confirms).to eq true

          sleep 0.25

          expect {
            Bunny::Timeout.timeout(2) do
              expect(ch.wait_for_confirms).to eq true
            end
          }.not_to raise_error

        end

        it "raises an error when called on a closed channel" do
          ch = connection.create_channel

          ch.confirm_select

          ch.close

          expect {
            ch.wait_for_confirms
          }.to raise_error(Bunny::ChannelAlreadyClosed)
        end
      end

      context "when some of the messages get nacked" do
        it "puts the nacks in the nacked_set" do
          ch = connection.create_channel
          expect(ch).not_to be_using_publisher_confirmations

          ch.confirm_select
          expect(ch).to be_using_publisher_confirmations

          q  = ch.queue("", exclusive: true)
          x  = ch.default_exchange

          n.times do
            x.publish("xyzzy", routing_key: q.name)
          end

          #be sneaky to simulate a nack
          nacked_tag = nil
          ch.instance_variable_get(:@unconfirmed_set_mutex).synchronize do
            expect(ch.unconfirmed_set).to_not be_empty
            nacked_tag = ch.unconfirmed_set.reduce(ch.next_publish_seq_no - 1) { |lowest, i| i < lowest ? i : lowest }
            ch.handle_ack_or_nack(nacked_tag, false, true)
          end

          expect(ch.nacked_set).not_to be_empty
          expect(ch.nacked_set).to include(nacked_tag)

          expect(ch.next_publish_seq_no).to eq n + 1
          expect(ch.wait_for_confirms).to eq false

          expect(ch.nacked_set).not_to be_empty
          expect(ch.nacked_set).to include(nacked_tag)

          sleep 0.25
          expect(q.message_count).to eq n
          q.purge

          ch.close
        end
      end
    end
  end

  context "with a multi-threaded connection" do
    let(:connection) do
      c = Bunny.new(username: "bunny_gem", password: "bunny_password", vhost: "bunny_testbed", continuation_timeout: 10000)
      c.start
      c
    end

    include_examples "publish confirms"

    it "returns only when all confirmations for publishes are received" do
      ch = connection.create_channel

      operations_log = []
      operations_log_mutex = Mutex.new
      acks_received = Queue.new

      log_acks = proc do |tag, _, is_nack|
        operations_log_mutex.synchronize do
          operation = "#{'n' if is_nack}ack_#{tag}"
          operations_log << operation unless operations_log.include?(operation)
        end
        acks_received << true
      end

      ch.confirm_select(log_acks)

      x = ch.default_exchange
      q = ch.temporary_queue

      x.publish('msg', routing_key: q.name)

      # wait for the confirmation to arrive
      acks_received.pop

      # artificially simulate a slower ack. the test should work properly even
      # without this patch, but it's here just to be sure we catch it.
      def (x.channel).handle_ack_or_nack(delivery_tag_before_offset, multiple, nack)
        sleep 0.1
        super
      end

      x.publish('msg', routing_key: q.name)
      x.publish('msg', routing_key: q.name)

      if x.wait_for_confirms
        operations_log_mutex.synchronize do
          operations_log << 'all_confirmed'
        end
      end

      # wait for all the confirmations to arrive
      acks_received.pop
      acks_received.pop

      expect(operations_log).to eq([
        'ack_1',
        'ack_2',
        'ack_3',
        'all_confirmed',
      ])
    end
  end

  context "with a single-threaded connection" do
    let(:connection) do
      c = Bunny.new(username: "bunny_gem", password: "bunny_password", vhost: "bunny_testbed", continuation_timeout: 10000, threaded: false)
      c.start
      c
    end

    include_examples "publish confirms"
  end
end
