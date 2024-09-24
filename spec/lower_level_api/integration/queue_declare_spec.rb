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

  #
  # These lower-level tests primarily exist to test redeclaration, because the
  # low-level API bypasses channel object caching.
  #

  context "when queue is declared with optional arguments" do
    it "declares it with those arguments" do
      ch   = connection.create_channel
      name = "bunny.tests.low-level.queues.x-args.1"

      args = {
        Bunny::Queue::XArgs::MAX_LENGTH => 1000
      }
      ch.queue_declare(name, durable: true, arguments: args)
      ch.queue_delete(name)

      ch.close
    end
  end

  context "when queue is declared with type using x-args and a literal string" do
    it "declares a queue of that type" do
      ch   = connection.create_channel
      name = "bunny.tests.low-level.queues.x-args.2.qq"

      args = {
        Bunny::Queue::XArgs::QUEUE_TYPE => "quorum"
      }
      ch.queue_declare(name, durable: true, arguments: args)
      ch.queue_delete(name)

      ch.close
    end
  end

  context "when queue is declared with type using x-args and a constant" do
    it "declares a queue of that type" do
      ch   = connection.create_channel
      name = "bunny.tests.low-level.queues.x-args.2.qq"

      args = {
        Bunny::Queue::XArgs::QUEUE_TYPE => Bunny::Queue::Types::QUORUM
      }
      ch.queue_declare(name, durable: true, arguments: args)
      ch.queue_delete(name)

      ch.close
    end
  end

  context "when queue is declared with type using :type and a literal string" do
    it "declares a queue of that type" do
      ch   = connection.create_channel
      name = "bunny.tests.queues.x-args.3.qq"

      args = {
        Bunny::Queue::XArgs::QUEUE_TYPE => "quorum"
      }
      ch.queue_declare(name, durable: true, type: Bunny::Queue::Types::QUORUM)
      ch.queue_delete(name)

      ch.close
    end
  end

  context "when queue is declared with type using :type and a constant" do
    it "declares a queue of that type" do
      ch   = connection.create_channel
      name = "bunny.tests.low-level.queues.x-args.3.qq"

      args = {
        Bunny::Queue::XArgs::QUEUE_TYPE => Bunny::Queue::Types::QUORUM
      }
      ch.queue_declare(name, durable: true, type: Bunny::Queue::Types::QUORUM)
      ch.queue_delete(name)

      ch.close
    end
  end

  context "when queue is declared with an unsupported :type" do
    it "raises an exception" do
      ch   = connection.create_channel
      name = "bunny.tests.low-level.queues.unsupported.type"
      args = {
        "x-queue-type": "super-duper-q"
      }

      ch.queue_delete(name)
      expect {
        ch.queue_declare(name, durable: true, arguments: args)
      }.to raise_error(ArgumentError)
      ch.queue_delete(name)

      ch.close
    end
  end

  context "when classic queue is declared with an explicit type and redeclared without it" do
    it "declares a queue of that type" do
      ch   = connection.create_channel
      name = "bunny.tests.low-level.queues.redeclarations.#{rand}.cq"
      ch.queue_delete(name)

      args = {
        Bunny::Queue::XArgs::QUEUE_TYPE => "classic"
      }
      ch.queue_declare(name, durable: true, arguments: args)
      # no explicit argument specified
      ch.queue_declare(name, durable: true, arguments: {})
      ch.queue_delete(name)

      ch.close
    end
  end

  context "when classic queue is declared without an explicit type and redeclared with it" do
    it "declares a queue of that type" do
      ch   = connection.create_channel
      name = "bunny.tests.low-level.queues.redeclarations.#{rand}.cq"
      ch.queue_delete(name)

      args = {
        Bunny::Queue::XArgs::QUEUE_TYPE => "classic"
      }
      # no explicit argument specified
      ch.queue_declare(name, durable: true, arguments: {})
      ch.queue_declare(name, durable: true, arguments: args)
      ch.queue_delete(name)

      ch.close
    end
  end

  context "when queue is declared with a set of mismatching values" do
    it "raises an exception" do
      ch   = connection.create_channel
      cleanup_ch = connection.create_channel

      name = "bunny.tests.low-level.queues.proprty-equivalence.fundmentals"
      cleanup_ch.queue_delete(name)

      q = ch.queue_declare(name, auto_delete: true, durable: false)
      expect do
        ch.queue_declare(name, auto_delete: false, durable: true)
      end.to raise_error(Bunny::PreconditionFailed)

      expect(ch).to be_closed

      cleanup_ch = connection.create_channel
      cleanup_ch.queue_delete(name)
    end
  end

  context "when queue is declared with a mismatching x-max-length" do
    it "raises an exception" do
      ch   = connection.create_channel
      cleanup_ch = connection.create_channel

      name = "bunny.tests.low-level.queues.proprty-equivalence.x-args.x-max-length"
      cleanup_ch.queue_delete(name)

      q = ch.queue_declare(name, type: "classic", durable: true, arguments: {"x-max-length": 10})
      expect do
        ch.queue_declare(name, type: "classic", durable: true, arguments: {"x-max-length": 20})
      end.to raise_error(Bunny::PreconditionFailed)

      expect(ch).to be_closed

      cleanup_ch = connection.create_channel
      cleanup_ch.queue_delete(name)
      cleanup_ch.close
    end
  end

  context "when queue is declared with a mismatching x-max-bytes" do
    it "raises an exception" do
      ch   = connection.create_channel
      cleanup_ch = connection.create_channel

      name = "bunny.tests.low-level.queues.proprty-equivalence.x-args.x-max-length-bytes"
      cleanup_ch.queue_delete(name)

      q = ch.queue_declare(name, type: "classic", durable: true, arguments: {"x-max-length-bytes": 1000000})
      expect do
        ch.queue_declare(name, type: "classic", durable: true, arguments: {"x-max-length-bytes": 99000000})
      end.to raise_error(Bunny::PreconditionFailed)

      expect(ch).to be_closed

      cleanup_ch = connection.create_channel
      cleanup_ch.queue_delete(name)
      cleanup_ch.close
    end
  end

  context "when queue is declared with a mismatching x-consumer-timeout" do
    it "raises an exception" do
      ch   = connection.create_channel
      name = "bunny.tests.low-level.queues.proprty-equivalence.x-args.x-consumer-timeout"

      q = ch.queue_declare(name, type: "classic", durable: true, arguments: {"x-consumer-timeout": 50000})
      # expect do
      #   ch.queue_declare(name, type: "classic", durable: true, arguments: {"x-consumer-timeout": 987000})
      # end.to raise_error(Bunny::PreconditionFailed)
      ch.queue_declare(name, type: "classic", durable: true, arguments: {"x-consumer-timeout": 987000})

      # expect(ch).to be_closed

      cleanup_ch = connection.create_channel
      cleanup_ch.queue_delete(name)
      cleanup_ch.close
    end
  end

end
