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

  def server_version_at_least?(connection, version)
    reported = connection.server_properties["version"].to_s.split("-").first
    Gem::Version.new(reported) >= Gem::Version.new(version)
  end

  #
  # These lower-level tests primarily exist to test redeclaration, because the
  # low-level API bypasses channel object caching.
  #

  context "when a queue is declared with the low-level API" do
    it "records auto_delete and exclusive in the topology registry" do
      name = "bunny.tests.low-level.queues.recorded-properties"

      ch = connection.create_channel
      ch.queue_declare(name, durable: true, auto_delete: true, exclusive: false)

      recorded = connection.topology_registry.queues[name]
      expect(recorded.auto_delete?).to be true
      expect(recorded.exclusive?).to be false

      ch.queue_delete(name)
      ch.close
    end
  end

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

      q = ch.queue_declare(name, auto_delete: true, durable: true)
      expect do
        ch.queue_declare(name, auto_delete: false, durable: false)
      end.to raise_error(Bunny::PreconditionFailed)

      expect(ch).to be_closed

      cleanup_ch = connection.create_channel
      cleanup_ch.queue_delete(name)
    end
  end

  RSpec.shared_examples "enforces optional x-argument equivalence" do |arg, val1, val2, extra_args = {}, min_server_version = nil|
    it "raises an exception when optional argument #{arg} values do not match that of the original declaration" do
      if min_server_version && !server_version_at_least?(connection, min_server_version)
        skip "RabbitMQ #{min_server_version} or later is required to enforce #{arg} equivalence"
      end

      queue_name = "bunny.tests.low-level.queues.proprty-equivalence.x-args.#{arg}"

      ch   = connection.create_channel
      cleanup_ch = connection.create_channel
      cleanup_ch.queue_delete(queue_name)

      q = ch.queue_declare(queue_name, durable: true, arguments: extra_args.merge(arg => val1))
      expect do
        ch.queue_declare(queue_name, durable: true, arguments: extra_args.merge(arg => val2))
      end.to raise_error(Bunny::PreconditionFailed)

      expect(ch).to be_closed

      cleanup_ch.queue_delete(queue_name)
      cleanup_ch.close
    end
  end

  include_examples "enforces optional x-argument equivalence", "x-max-length", 100, 200
  include_examples "enforces optional x-argument equivalence", "x-max-length-bytes", 1000000, 99900000
  include_examples "enforces optional x-argument equivalence", "x-expires", 2200000, 5500000
  include_examples "enforces optional x-argument equivalence", "x-message-ttl", 3000, 5000
  # x-consumer-timeout is a quorum queue argument. RabbitMQ 4.2 and earlier
  # do not enforce its equivalence
  include_examples "enforces optional x-argument equivalence", "x-consumer-timeout", 10_000, 20_000,
                   {Bunny::Queue::XArgs::QUEUE_TYPE => Bunny::Queue::Types::QUORUM}, "4.3.0"


  RSpec.shared_examples "leniently verifies optional x-argument equivalence" do |arg, val1, val2, extra_args = {}|
    it "DOES NOT raise an exception when optional argument #{arg} values do not match that of the original declaration" do
      queue_name = "bunny.tests.low-level.queues.proprty-equivalence.x-args.#{arg}"

      ch   = connection.create_channel
      cleanup_ch = connection.create_channel
      cleanup_ch.queue_delete(queue_name)

      q = ch.queue_declare(queue_name, durable: true, arguments: extra_args.merge(arg => val1))
      # no exception raised
      ch.queue_declare(queue_name, durable: true, arguments: extra_args.merge(arg => val2))

      cleanup_ch.queue_delete(queue_name)
      cleanup_ch.close
    end
  end

  include_examples "leniently verifies optional x-argument equivalence", "x-alternate-exchange", "amq.fanout", "amq.topic"

end
