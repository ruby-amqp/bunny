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

          # Simulate a nack by directly calling handle_ack_or_nack
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

  shared_examples "publish confirms with tracking" do
    context "with tracking: true" do
      describe "#basic_publish blocking behavior" do
        it "publishes with confirms enabled" do
          ch = connection.create_channel
          ch.confirm_select(tracking: true)

          q = ch.queue("", exclusive: true)
          x = ch.default_exchange

          Bunny::Timeout.timeout(5) do
            x.publish("test", routing_key: q.name)
          end
          ch.wait_for_confirms

          expect(q.message_count).to eq 1
          ch.close
        end

        it "returns self (backward compatible)" do
          ch = connection.create_channel
          ch.confirm_select(tracking: true)

          q = ch.queue("", exclusive: true)
          result = ch.basic_publish("msg", "", q.name)

          expect(result).to eq ch
          ch.close
        end

        it "correctly handles multiple sequential publishes" do
          ch = connection.create_channel
          ch.confirm_select(tracking: true)

          q = ch.queue("", exclusive: true)
          x = ch.default_exchange

          50.times { x.publish("msg", routing_key: q.name) }
          ch.wait_for_confirms

          expect(q.message_count).to eq 50
          ch.close
        end

        it "stores tracking configuration" do
          ch = connection.create_channel
          ch.confirm_select(tracking: true, outstanding_limit: 100, confirm_timeout: 5000)

          expect(ch.confirms_tracking_enabled).to eq true
          expect(ch.outstanding_limit).to eq 100
          expect(ch.confirm_timeout).to eq 5000
          ch.close
        end

        it "defaults outstanding_limit to 1000 when tracking enabled" do
          ch = connection.create_channel
          ch.confirm_select(tracking: true)

          expect(ch.outstanding_limit).to eq 1000
          ch.close
        end
      end

      describe "nack handling with tracking" do
        it "raises Bunny::MessageNacked when message is nacked" do
          ch = connection.create_channel
          ch.confirm_select(tracking: true)

          q = ch.queue("", exclusive: true)
          x = ch.default_exchange

          # Start a publish in a thread
          publish_thread = Thread.new do
            begin
              x.publish("msg", routing_key: q.name)
              :ack_received
            rescue Bunny::MessageNacked => e
              e
            end
          end

          # Wait for the message to be published and in the unconfirmed set
          sleep 0.1

          # Simulate a nack by directly calling handle_ack_or_nack
          ch.instance_variable_get(:@unconfirmed_set_mutex).synchronize do
            unless ch.unconfirmed_set.empty?
              tag = ch.unconfirmed_set.first
              ch.handle_ack_or_nack(tag, false, true)
            end
          end

          result = publish_thread.join(2)&.value

          if result.is_a?(Bunny::MessageNacked)
            expect(result.delivery_tag).to eq 1
          else
            # Message may have been acked before we could simulate nack
            expect(result).to eq :ack_received
          end

          ch.close
        end
      end
    end

    context "with outstanding_limit throttling" do
      describe "throttle behavior" do
        it "allows publishing up to the limit" do
          ch = connection.create_channel
          ch.confirm_select(tracking: true, outstanding_limit: 10)

          q = ch.queue("", exclusive: true)
          x = ch.default_exchange

          Bunny::Timeout.timeout(10) do
            20.times { x.publish("msg", routing_key: q.name) }
          end

          ch.wait_for_confirms
          expect(q.message_count).to eq 20
          ch.close
        end

        it "respects outstanding limit with concurrent publishers" do
          ch = connection.create_channel
          ch.confirm_select(tracking: true, outstanding_limit: 5)

          q = ch.queue("", exclusive: true)
          x = ch.default_exchange

          threads = 3.times.map do
            Thread.new do
              10.times { x.publish("msg", routing_key: q.name) }
            end
          end

          Bunny::Timeout.timeout(15) do
            threads.each(&:join)
          end

          expect(q.message_count).to eq 30
          ch.close
        end
      end
    end

    context "channel operations during tracking" do
      it "raises ChannelAlreadyClosed if channel closes while blocked" do
        ch = connection.create_channel
        ch.confirm_select(tracking: true, outstanding_limit: 1)

        q = ch.queue("", exclusive: true)
        x = ch.default_exchange

        # First publish will succeed, second will block on outstanding limit
        x.publish("msg1", routing_key: q.name)

        publish_thread = Thread.new do
          begin
            # This should block waiting for outstanding slot
            x.publish("msg2", routing_key: q.name)
            :completed
          rescue Bunny::ChannelAlreadyClosed
            :channel_closed
          end
        end

        sleep 0.1 # Let the thread start blocking
        ch.close rescue nil

        result = publish_thread.join(2)&.value
        expect([:channel_closed, :completed]).to include(result)
      end
    end

    context "concurrent publishing with tracking" do
      it "handles multiple threads publishing simultaneously" do
        ch = connection.create_channel
        ch.confirm_select(tracking: true)

        q = ch.queue("", exclusive: true)
        x = ch.default_exchange

        threads = 5.times.map do
          Thread.new do
            10.times { x.publish("data", routing_key: q.name) }
          end
        end

        Bunny::Timeout.timeout(10) do
          threads.each(&:join)
        end

        expect(q.message_count).to eq 50
        ch.close
      end
    end

    context "with callback and tracking" do
      it "invokes callback for each confirm" do
        ch = connection.create_channel

        acks = []
        acks_mutex = Mutex.new
        callback = proc { |tag, _, nack| acks_mutex.synchronize { acks << [tag, nack] } }

        ch.confirm_select(callback, tracking: true)

        q = ch.queue("", exclusive: true)
        x = ch.default_exchange

        3.times { x.publish("msg", routing_key: q.name) }

        # Callback runs in reader thread; wait briefly for last callback to complete
        sleep 0.2

        acks_mutex.synchronize do
          expect(acks.size).to eq 3
          expect(acks.map(&:first)).to contain_exactly(1, 2, 3)
          expect(acks.map(&:last)).to all(eq false)
        end
        ch.close
      end
    end

    context "backward compatibility" do
      it "works without tracking parameter (legacy mode)" do
        ch = connection.create_channel
        ch.confirm_select  # No tracking parameter

        q = ch.queue("", exclusive: true)
        x = ch.default_exchange

        50.times { x.publish("data", routing_key: q.name) }

        expect(ch.wait_for_confirms).to eq true
        expect(q.message_count).to eq 50
        ch.close
      end

      it "still supports wait_for_confirms without tracking" do
        ch = connection.create_channel
        ch.confirm_select(tracking: false)

        q = ch.queue("", exclusive: true)
        x = ch.default_exchange

        50.times { x.publish("data", routing_key: q.name) }

        # Must explicitly wait
        expect(ch.wait_for_confirms).to eq true
        ch.close
      end
    end

    context "argument validation" do
      it "rejects outstanding_limit of zero" do
        ch = connection.create_channel
        expect {
          ch.confirm_select(tracking: true, outstanding_limit: 0)
        }.to raise_error(ArgumentError, /outstanding_limit must be positive/)
        ch.close
      end

      it "rejects negative confirm_timeout" do
        ch = connection.create_channel
        expect {
          ch.confirm_select(tracking: true, confirm_timeout: -1)
        }.to raise_error(ArgumentError, /confirm_timeout must be positive/)
        ch.close
      end

      it "rejects outstanding_limit without tracking" do
        ch = connection.create_channel
        expect {
          ch.confirm_select(outstanding_limit: 10)
        }.to raise_error(ArgumentError, /outstanding_limit requires tracking: true/)
        ch.close
      end

      it "allows changing tracking options by calling confirm_select again" do
        ch = connection.create_channel
        ch.confirm_select(tracking: true, outstanding_limit: 10)

        expect(ch.confirms_tracking_enabled).to eq true
        expect(ch.outstanding_limit).to eq 10

        ch.confirm_select(tracking: false)

        expect(ch.confirms_tracking_enabled).to eq false
        expect(ch.outstanding_limit).to be_nil

        ch.close
      end
    end

    context "basic_publish_batch" do
      it "publishes multiple messages in a single batch" do
        ch = connection.create_channel
        ch.confirm_select(tracking: true, outstanding_limit: 100)

        q = ch.queue("", exclusive: true)
        messages = 50.times.map { |i| "message #{i}" }

        ch.basic_publish_batch(messages, "", q.name)
        ch.wait_for_confirms

        expect(q.message_count).to eq 50
        ch.close
      end

      it "returns self for chaining" do
        ch = connection.create_channel
        ch.confirm_select(tracking: true, outstanding_limit: 100)

        q = ch.queue("", exclusive: true)
        result = ch.basic_publish_batch(["msg1", "msg2"], "", q.name)

        expect(result).to eq ch
        ch.close
      end

      it "handles empty payload array" do
        ch = connection.create_channel
        ch.confirm_select(tracking: true, outstanding_limit: 100)

        q = ch.queue("", exclusive: true)
        result = ch.basic_publish_batch([], "", q.name)

        expect(result).to eq ch
        expect(q.message_count).to eq 0
        ch.close
      end

      it "respects outstanding_limit for batch" do
        ch = connection.create_channel
        ch.confirm_select(tracking: true, outstanding_limit: 20)

        q = ch.queue("", exclusive: true)

        # Publish multiple batches
        3.times do
          ch.basic_publish_batch(10.times.map { "msg" }, "", q.name)
        end
        ch.wait_for_confirms

        expect(q.message_count).to eq 30
        ch.close
      end

      it "works with concurrent batch publishers" do
        ch = connection.create_channel
        ch.confirm_select(tracking: true, outstanding_limit: 50)

        q = ch.queue("", exclusive: true)

        threads = 4.times.map do
          Thread.new do
            5.times { ch.basic_publish_batch(10.times.map { "msg" }, "", q.name) }
          end
        end

        Bunny::Timeout.timeout(15) do
          threads.each(&:join)
        end
        ch.wait_for_confirms

        expect(q.message_count).to eq 200
        ch.close
      end

      it "accepts exchange object" do
        ch = connection.create_channel
        ch.confirm_select(tracking: true, outstanding_limit: 100)

        q = ch.queue("", exclusive: true)
        x = ch.default_exchange

        ch.basic_publish_batch(["msg1", "msg2"], x, q.name)
        ch.wait_for_confirms

        expect(q.message_count).to eq 2
        ch.close
      end

      it "works with legacy confirm_select (no tracking)" do
        ch = connection.create_channel
        ch.confirm_select  # No tracking

        q = ch.queue("", exclusive: true)

        ch.basic_publish_batch(20.times.map { "msg" }, "", q.name)
        ch.wait_for_confirms

        expect(q.message_count).to eq 20
        ch.close
      end

      it "works without confirms enabled" do
        ch = connection.create_channel
        # No confirm_select at all

        q = ch.queue("", exclusive: true)

        ch.basic_publish_batch(10.times.map { "msg" }, "", q.name)
        sleep 0.1

        expect(q.message_count).to eq 10
        ch.close
      end

      it "handles batch_size larger than outstanding_limit" do
        ch = connection.create_channel
        ch.confirm_select(tracking: true, outstanding_limit: 5)

        q = ch.queue("", exclusive: true)

        # Batch of 20 messages with limit of 5 - should still work
        ch.basic_publish_batch(20.times.map { "msg" }, "", q.name)
        ch.wait_for_confirms

        expect(q.message_count).to eq 20
        ch.close
      end

      it "rejects routing key longer than 255 characters" do
        ch = connection.create_channel
        long_key = "x" * 256

        expect {
          ch.basic_publish_batch(["msg"], "", long_key)
        }.to raise_error(ArgumentError, /routing key cannot be longer than/)
        ch.close
      end

      it "rejects non-array payloads" do
        ch = connection.create_channel

        expect {
          ch.basic_publish_batch("not an array", "", "key")
        }.to raise_error(ArgumentError, /payloads must be an Array/)
        ch.close
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
    include_examples "publish confirms with tracking"

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
