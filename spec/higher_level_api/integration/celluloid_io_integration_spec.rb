require 'celluloid/current'
require 'celluloid/io'
require "spec_helper"

class RabbitMQActor
  include Celluloid::IO

  attr_reader :c

  def initialize
    @c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed")
    @c.start
  end

  def terminate
    @c.stop
    super
  end
end

class RabbitMQSampleProducer < RabbitMQActor
  def publish_basic
    ch = @c.create_channel

    q  = ch.queue("", :exclusive => true)
    x  = ch.fanout("amq.fanout")
    q.bind(x)

    rk = "a" * 254
    x.publish("xyzzy", :routing_key => rk, :persistent => true)

    sleep(1)
    message_count = q.message_count

    _, _, payload = q.pop

    ch.close

    return message_count, payload
  end
end

class RabbitMQSampleConsumer < RabbitMQActor
  def consume_basic(queue_name)
    delivered_keys = []
    delivered_data = []

    t = Thread.new do
      ch = @c.create_channel
      q = ch.queue(queue_name, :auto_delete => true, :durable => false)
      q.subscribe(:exclusive => false, :manual_ack => false) do |delivery_info, properties, payload|
        delivered_keys << delivery_info.routing_key
        delivered_data << payload
      end
    end
    t.abort_on_exception = true
    sleep 0.5

    ch = @c.create_channel
    x  = ch.default_exchange
    x.publish("hello", :routing_key => queue_name)

    sleep 0.7

    message_count = ch.queue(queue_name, :auto_delete => true, :durable => false).message_count

    ch.close

    return delivered_keys, delivered_data, message_count
  end
end

describe 'Celluloid::IO integration' do
  before do
    Celluloid.boot
  end

  after do
    Celluloid.shutdown
  end

  context 'when intializing a new RabbitMQActor' do
    it 'connects successfully' do
      actor = RabbitMQActor.new

      actor.terminate
    end

    it 'converts the socket to a Celluloid::IO socket' do
      actor = RabbitMQActor.new
      expect(actor.c.transport.socket).to be_instance_of(Celluloid::IO::TCPSocket)
      actor.terminate
    end
  end

  context 'when producing a message' do
    it 'is available in RabbitMQ' do
      actor = RabbitMQSampleProducer.new
      message_count, payload = actor.publish_basic

      expect(message_count).to eq 1
      expect(payload).to eq "xyzzy"
    end
  end

  context 'when consuming a message' do
    let(:queue_name) { 'celluloidiotest' }

    it 'registers the consumer' do
      actor = RabbitMQSampleConsumer.new
      delivered_keys, delivered_data, message_count = actor.consume_basic(queue_name)

      expect(delivered_keys).to include(queue_name)
      expect(delivered_data).to include("hello")
      expect(message_count).to eq(0)

    end
  end
end
