require "spec_helper"

describe Bunny::Queue do
  let(:connection) do
    c = Bunny.new(user: "bunny_gem", password: "bunny_password", vhost: "bunny_testbed")
    c.start
    c
  end

  after :each do
    connection.close if connection.open?
  end

  context "when queue name is specified" do
    let(:name) { "a queue declared at #{Bunny::Timestamp.now.to_i}" }

    it "declares a new queue with that name" do
      ch   = connection.create_channel

      q    = ch.queue(name)
      expect(q.name).to eq name

      q.delete
      ch.close
    end

    it "caches that queue" do
      ch   = connection.create_channel

      q = ch.queue(name)
      expect(ch.queue(name).object_id).to eq q.object_id

      q.delete
      ch.close
    end
  end


  context "when queue name is passed as an empty string" do
    it "uses server-assigned queue name" do
      ch   = connection.create_channel

      q = ch.queue("")
      expect(q.name).not_to be_empty
      expect(q.name).to match /^amq.gen.+/
      expect(q).to be_server_named
      q.delete

      ch.close
    end
  end


  context "when a nil is passed for queue name" do
    it "throws an error" do
      ch   = connection.create_channel

      expect {
        ch.queue(nil, durable: true, auto_delete: false)
      }.to raise_error(ArgumentError)
    end
  end


  context "when queue is declared as durable" do
    it "declares it as durable" do
      ch   = connection.create_channel

      q = ch.queue("bunny.tests.queues.durable", durable: true)
      expect(q).to be_durable
      expect(q).not_to be_auto_delete
      expect(q).not_to be_exclusive
      expect(q.arguments).to be_nil
      q.delete

      ch.close
    end
  end


  context "when queue is declared as exclusive" do
    it "declares it as exclusive" do
      ch   = connection.create_channel

      q = ch.queue("bunny.tests.queues.exclusive", exclusive: true)
      expect(q).to be_exclusive
      expect(q).not_to be_durable
      q.delete

      ch.close
    end
  end


  context "when queue is declared as auto-delete" do
    it "declares it as auto-delete" do
      ch   = connection.create_channel

      q = ch.queue("bunny.tests.queues.auto-delete", auto_delete: true)
      expect(q).to be_auto_delete
      expect(q).not_to be_exclusive
      expect(q).not_to be_durable
      q.delete

      ch.close
    end
  end

  context "when queue is declared with optional arguments" do
    it "declares it with those arguments" do
      ch   = connection.create_channel

      args = {
        Bunny::Queue::XArgs::MAX_LENGTH => 1000
      }
      q = ch.queue("bunny.tests.queues.x-args.1", durable: true, arguments: args)
      expect(q).not_to be_auto_delete
      expect(q).not_to be_exclusive
      expect(q).to be_durable
      expect(q.arguments).to eq(args)
      q.delete

      ch.close
    end
  end

  context "when queue is declared with type using x-args and a literal string" do
    it "declares a queue of that type" do
      ch   = connection.create_channel

      args = {
        Bunny::Queue::XArgs::QUEUE_TYPE => "quorum"
      }
      q = ch.queue("bunny.tests.queues.x-args.2.qq", durable: true, arguments: args)
      expect(q).not_to be_auto_delete
      expect(q).not_to be_exclusive
      expect(q).to be_durable
      expect(q.arguments).to eq(args)
      q.delete

      ch.close
    end
  end

  context "when queue is declared with type using x-args and a constant" do
    it "declares a queue of that type" do
      ch   = connection.create_channel

      args = {
        Bunny::Queue::XArgs::QUEUE_TYPE => Bunny::Queue::Types::QUORUM
      }
      q = ch.queue("bunny.tests.queues.x-args.2.qq", durable: true, arguments: args)
      expect(q).not_to be_auto_delete
      expect(q).not_to be_exclusive
      expect(q).to be_durable
      expect(q.arguments).to eq(args)
      q.delete

      ch.close
    end
  end

  context "when queue is declared with type using :type and a literal string" do
    it "declares a queue of that type" do
      ch   = connection.create_channel

      args = {
        Bunny::Queue::XArgs::QUEUE_TYPE => "quorum"
      }
      q = ch.queue("bunny.tests.queues.x-args.3.qq", durable: true, type: Bunny::Queue::Types::QUORUM)
      expect(q).not_to be_auto_delete
      expect(q).not_to be_exclusive
      expect(q).to be_durable
      expect(q.arguments).to eq(args)
      q.delete

      ch.close
    end
  end

  context "when queue is declared with type using :type and a constant" do
    it "declares a queue of that type" do
      ch   = connection.create_channel

      args = {
        Bunny::Queue::XArgs::QUEUE_TYPE => Bunny::Queue::Types::QUORUM
      }
      q = ch.queue("bunny.tests.queues.x-args.3.qq", durable: true, type: Bunny::Queue::Types::QUORUM)
      expect(q).not_to be_auto_delete
      expect(q).not_to be_exclusive
      expect(q).to be_durable
      expect(q.arguments).to eq(args)
      q.delete

      ch.close
    end
  end

  context "when a quorum queue is declared using a helper" do
    it "declares a quorum queue" do
      ch   = connection.create_channel

      args = {
        Bunny::Queue::XArgs::MAX_LENGTH => 1000,
        Bunny::Queue::XArgs::QUEUE_TYPE => Bunny::Queue::Types::QUORUM
      }
      q = ch.quorum_queue("bunny.tests.queues.qq.1", durable: false, exclusive: true, arguments: {
        Bunny::Queue::XArgs::MAX_LENGTH => 1000
      })
      expect(q).not_to be_auto_delete
      expect(q).not_to be_exclusive
      expect(q).to be_durable
      expect(q.arguments).to eq(args)
      q.delete

      ch.close
    end
  end

  context "when a stream 'queue' is declared using a helper" do
    it "declares a stream" do
      ch   = connection.create_channel

      args = {
        Bunny::Queue::XArgs::MAX_LENGTH => 1000,
        Bunny::Queue::XArgs::QUEUE_TYPE => Bunny::Queue::Types::STREAM
      }
      q = ch.stream("bunny.tests.queues.sq.1", durable: false, exclusive: true, arguments: {
        Bunny::Queue::XArgs::MAX_LENGTH => 1000
      })
      expect(q).not_to be_auto_delete
      expect(q).not_to be_exclusive
      expect(q).to be_durable
      expect(q.arguments).to eq(args)
      q.delete

      ch.close
    end
  end

  context "when queue is declared with an unsupported :type" do
    it "raises an exception" do
      ch   = connection.create_channel

      expect {
        ch.queue("bunny.tests.queues.unsupported.type", durable: true, type: "super-duper-q")
      }.to raise_error(ArgumentError)

      ch.close
    end
  end

  context "when queue is declared with a mismatching auto-delete property value" do
    it "raises an exception" do
      ch   = connection.create_channel

      q = ch.queue("bunny.tests.queues.auto-delete", auto_delete: true, durable: false)
      expect {
        # force re-declaration
        ch.queue_declare(q.name, auto_delete: false, durable: false)
      }.to raise_error(Bunny::PreconditionFailed)

      expect(ch).to be_closed

      cleanup_ch = connection.create_channel
      cleanup_ch.queue_delete(q.name)
    end
  end

  context "when queue is declared with a mismatching durable property value" do
    it "raises an exception" do
      ch   = connection.create_channel

      q = ch.queue("bunny.tests.queues.durable", durable: true)
      expect {
        # force re-declaration
        ch.queue_declare(q.name, durable: false)
      }.to raise_error(Bunny::PreconditionFailed)

      expect(ch).to be_closed

      cleanup_ch = connection.create_channel
      cleanup_ch.queue_delete(q.name)
    end
  end

  context "when queue is declared with a mismatching exclusive property value" do
    it "raises an exception" do
      ch   = connection.create_channel

      q = ch.queue("bunny.tests.queues.exclusive.#{rand}", exclusive: true)
      # when there's an exclusivity property mismatch, a different error
      # (405 RESOURCE_LOCKED) is used. This is a leaked queue exclusivity/ownership
      # implementation detail that's now basically a feature. MK.
      expect {
        # force re-declaration
        ch.queue_declare(q.name, exclusive: false)
      }.to raise_error(Bunny::ResourceLocked)

      expect(ch).to be_closed
    end
  end

  context "when queue is declared with a set of mismatching values" do
    it "raises an exception" do
      ch   = connection.create_channel

      q = ch.queue("bunny.tests.queues.proprty-equivalence", auto_delete: true, durable: false)
      expect {
        # force re-declaration
        ch.queue_declare(q.name, auto_delete: false, durable: true)
      }.to raise_error(Bunny::PreconditionFailed)

      expect(ch).to be_closed

      cleanup_ch = connection.create_channel
      cleanup_ch.queue_delete(q.name)
    end
  end


  context "when queue is declared with message TTL" do
    let(:args) do
      # in ms
      {"x-message-ttl" => 1000}
    end

    it "causes all messages in it to have a TTL" do
      ch   = connection.create_channel

      q = ch.queue("bunny.tests.queues.with-arguments.ttl", arguments:  args, exclusive: true)
      expect(q.arguments).to eq args

      q.publish("xyzzy")
      sleep 0.1

      expect(q.message_count).to eq 1
      sleep 1.5
      expect(q.message_count).to eq 0

      ch.close
    end
  end


  context "when queue is declared with priorities" do
    let(:args) do
      {"x-max-priority" => 5}
    end

    it "enables priority implementation" do
      c = Bunny.new(user: "bunny_gem", password: "bunny_password", vhost: "bunny_testbed")
      c.start

      ch   = c.create_channel
      ch.confirm_select

      q = ch.queue("bunny.tests.queues.with-arguments.priority #{rand}", arguments: args, exclusive: true)
      expect(q.arguments).to eq args

      q.publish("xyzzy")
      ch.wait_for_confirms
      sleep 0.1

      # this test only does sanity checking,
      # without trying to actually test prioritisation.
      #
      # added to guard against issues such as
      # https://github.com/rabbitmq/rabbitmq-server/issues/488
      expect(q.message_count).to eq 1

      ch.close
    end
  end


  describe "#queue_exists?" do
    context "when a queue exists" do
      it "returns true" do
        ch = connection.create_channel
        q  = ch.queue("bunny.tests.queues.exists", durable: true, arguments: {"x-expires" => 5000})

        expect(connection.queue_exists?(q.name)).to eq true
      end
    end

    context "when a queue DOES NOT exist" do
      it "returns false" do
        expect(connection.queue_exists?("suf89u9a4jo3ndnakls##{Bunny::Timestamp.now.to_i}")).to eq false
      end
    end
    
    context "when a exclusive queue exists" do
      it "returns true" do
        ch = connection.create_channel
        q  = ch.queue("bunny.tests.queues.exists.exclusive", exclusive: true)

        expect(connection.queue_exists?(q.name)).to eq true
      end
    end
  end



  unless ENV["CI"]
    # requires RabbitMQ 3.1+
    context "when queue is declared with bounded length" do
      let(:n) { 10 }
      let(:args) do
        # in ms
        {"x-max-length" => n}
      end

      # see http://www.rabbitmq.com/maxlength.html for more info
      it "causes the queue to be bounded" do
        ch   = connection.create_channel

        q = ch.queue("bunny.tests.queues.with-arguments.max-length", arguments:  args, exclusive: true)
        expect(q.arguments).to eq args

        (n * 10).times do
          q.publish("xyzzy")
        end

        expect(q.message_count).to eq n
        (n * 5).times do
          q.publish("xyzzy")
        end

        expect(q.message_count).to eq n
        q.delete

        ch.close
      end
    end
  end
end
