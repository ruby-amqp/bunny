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

  RSpec.shared_examples "verifies optional x-argument equivalence" do |arg, val1, val2|
    it "raises an exception when optional argument #{arg} values do not match that of the original declaration" do
      queue_name = "bunny.tests.low-level.queues.proprty-equivalence.x-args.#{arg}"

      ch   = connection.create_channel
      cleanup_ch = connection.create_channel
      cleanup_ch.queue_delete(queue_name)

      q = ch.queue_declare(queue_name, type: "classic", durable: true, arguments: {arg => val1})
      expect do
        ch.queue_declare(queue_name, type: "classic", durable: true, arguments: {arg => val2})
      end.to raise_error(Bunny::PreconditionFailed)

      expect(ch).to be_closed

      cleanup_ch.queue_delete(queue_name)
      cleanup_ch.close
    end
  end

  include_examples "verifies optional x-argument equivalence", "x-max-length", 100, 200
  include_examples "verifies optional x-argument equivalence", "x-max-length-bytes", 1000000, 99900000
  include_examples "verifies optional x-argument equivalence", "x-expires", 2200000, 5500000
  include_examples "verifies optional x-argument equivalence", "x-message-ttl", 3000, 5000


  RSpec.shared_examples "ignores optional x-argument equivalence" do |arg, val1, val2|
    it "DOES NOT raise an exception when optional argument #{arg} values do not match that of the original declaration" do
      queue_name = "bunny.tests.low-level.queues.proprty-equivalence.x-args.#{arg}"

      ch   = connection.create_channel
      cleanup_ch = connection.create_channel
      cleanup_ch.queue_delete(queue_name)

      q = ch.queue_declare(queue_name, type: "classic", durable: true, arguments: {arg => val1})
      # no exception raised
      ch.queue_declare(queue_name, type: "classic", durable: true, arguments: {arg => val2})

      cleanup_ch.queue_delete(queue_name)
      cleanup_ch.close
    end
  end

  include_examples "ignores optional x-argument equivalence", "x-consumer-timeout", 10_000, 20_000
  include_examples "ignores optional x-argument equivalence", "x-alternate-exchange", "amq.fanout", "amq.topic"

end
