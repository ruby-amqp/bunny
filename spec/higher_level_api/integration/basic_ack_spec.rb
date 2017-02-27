require "spec_helper"

describe Bunny::Channel, "#ack" do
  let(:connection) do
    c = Bunny.new(username: "bunny_gem", password: "bunny_password", vhost: "bunny_testbed")
    c.start
    c
  end

  after :each do
    connection.close if connection.open?
  end

  context "with a valid (known) delivery tag" do
    it "acknowledges a message" do
      ch = connection.create_channel
      q  = ch.queue("bunny.basic.ack.manual-acks", exclusive: true)
      x  = ch.default_exchange

      x.publish("bunneth", routing_key: q.name)
      sleep 0.5
      expect(q.message_count).to eq 1
      delivery_details, properties, content = q.pop(manual_ack: true)

      ch.ack(delivery_details.delivery_tag, true)
      ch.close

      ch = connection.create_channel
      q  = ch.queue("bunny.basic.ack.manual-acks", exclusive: true)
      expect(q.message_count).to eq 0
      ch.close
    end
  end

  context "with a valid (known) delivery tag (multiple = true)" do
    it "acknowledges a message" do
      ch = connection.create_channel
      q  = ch.queue("bunny.basic.ack.manual-acks", exclusive: true)
      x  = ch.default_exchange

      x.publish("bunneth", routing_key: q.name)
      x.publish("bunneth", routing_key: q.name)
      sleep 0.5
      expect(q.message_count).to eq 2
      delivery_details_1, _properties, _content = q.pop(manual_ack: true)
      delivery_details_2, _properties, _content = q.pop(manual_ack: true)

      ch.ack(delivery_details_2.delivery_tag, true)
      ch.close

      ch = connection.create_channel
      q  = ch.queue("bunny.basic.ack.manual-acks", exclusive: true)
      expect(q.message_count).to eq 0
      ch.close
    end
  end

  context "with a valid (known) delivery tag (multiple = false)" do
    it "acknowledges a message" do
      ch = connection.create_channel
      q  = ch.queue("bunny.basic.ack.manual-acks", exclusive: true)
      x  = ch.default_exchange

      x.publish("bunneth", routing_key: q.name)
      x.publish("bunneth", routing_key: q.name)
      sleep 0.5
      expect(q.message_count).to eq 2
      delivery_details_1, _properties, _content = q.pop(manual_ack: true)
      delivery_details_2, _properties, _content = q.pop(manual_ack: true)

      ch.ack(delivery_details_2.delivery_tag, false)
      ch.close

      ch = connection.create_channel
      q  = ch.queue("bunny.basic.ack.manual-acks", exclusive: true)
      expect(q.message_count).to eq 1
      ch.close
    end
  end

  context "with a valid (known) delivery tag and automatic ack mode" do
    it "results in a channel exception" do
      ch = connection.create_channel
      q  = ch.queue("bunny.basic.ack.manual-acks", exclusive: true)
      x  = ch.default_exchange

      q.subscribe(manual_ack: false) do |delivery_info, properties, payload|
        ch.ack(delivery_info.delivery_tag, false)
      end

      x.publish("bunneth", routing_key: q.name)
      sleep 0.5
      expect do
        q.message_count
      end.to raise_error(Bunny::ChannelAlreadyClosed)
    end
  end

  context "with an invalid (random) delivery tag" do
    it "causes a channel-level error" do
      ch = connection.create_channel
      q  = ch.queue("bunny.basic.ack.unknown-delivery-tag", exclusive: true)
      x  = ch.default_exchange

      x.publish("bunneth", routing_key: q.name)
      sleep 0.5
      expect(q.message_count).to eq 1
      _, _, content = q.pop(manual_ack: true)

      ch.on_error do |ch, channel_close|
        @channel_close = channel_close
      end
      ch.ack(82, true)
      sleep 0.25

      expect(@channel_close.reply_code).to eq AMQ::Protocol::PreconditionFailed::VALUE
    end
  end

  context "with a valid (known) delivery tag" do
    it "gets a depricated message warning for using :ack" do
      ch = connection.create_channel
      q  = ch.queue("bunny.basic.ack.manual-acks", exclusive: true)
      x  = ch.default_exchange

      x.publish("bunneth", routing_key: q.name)
      sleep 0.5
      expect(q.message_count).to eq 1

      orig_stderr = $stderr
      $stderr = StringIO.new

      delivery_details, properties, content = q.pop(ack: true)

      $stderr.rewind
      expect($stderr.string.chomp).to eq("[DEPRECATION] `:ack` is deprecated.  Please use `:manual_ack` instead.\n[DEPRECATION] `:ack` is deprecated.  Please use `:manual_ack` instead.")

      $stderr = orig_stderr

      ch.ack(delivery_details.delivery_tag, true)
      ch.close

      ch = connection.create_channel
      q  = ch.queue("bunny.basic.ack.manual-acks", exclusive: true)
      expect(q.message_count).to eq 0
      ch.close
    end
  end
end

describe Bunny::Channel, "#basic_ack" do
  let(:connection) do
    c = Bunny.new(username: "bunny_gem", password: "bunny_password", vhost: "bunny_testbed")
    c.start
    c
  end

  after :each do
    connection.close if connection.open?
  end

  context "with a valid (known) delivery tag (multiple = true)" do
    it "acknowledges a message" do
      ch = connection.create_channel
      q  = ch.queue("bunny.basic.ack.manual-acks", exclusive: true)
      x  = ch.default_exchange

      x.publish("bunneth", routing_key: q.name)
      x.publish("bunneth", routing_key: q.name)
      sleep 0.5
      expect(q.message_count).to eq 2
      delivery_details_1, _properties, _content = q.pop(manual_ack: true)
      delivery_details_2, _properties, _content = q.pop(manual_ack: true)

      ch.basic_ack(delivery_details_2.delivery_tag.to_i, true)
      ch.close

      ch = connection.create_channel
      q  = ch.queue("bunny.basic.ack.manual-acks", exclusive: true)
      expect(q.message_count).to eq 0
      ch.close
    end
  end

  context "with a valid (known) delivery tag (multiple = false)" do
    it "acknowledges a message" do
      ch = connection.create_channel
      q  = ch.queue("bunny.basic.ack.manual-acks", exclusive: true)
      x  = ch.default_exchange

      x.publish("bunneth", routing_key: q.name)
      x.publish("bunneth", routing_key: q.name)
      sleep 0.5
      expect(q.message_count).to eq 2
      delivery_details_1, _properties, _content = q.pop(manual_ack: true)
      delivery_details_2, _properties, _content = q.pop(manual_ack: true)

      ch.basic_ack(delivery_details_2.delivery_tag.to_i, false)
      ch.close

      ch = connection.create_channel
      q  = ch.queue("bunny.basic.ack.manual-acks", exclusive: true)
      expect(q.message_count).to eq 1
      ch.close
    end
  end

  context "with a valid (known) delivery tag (multiple = default)" do
    it "acknowledges a message" do
      ch = connection.create_channel
      q  = ch.queue("bunny.basic.ack.manual-acks", exclusive: true)
      x  = ch.default_exchange

      x.publish("bunneth", routing_key: q.name)
      x.publish("bunneth", routing_key: q.name)
      sleep 0.5
      expect(q.message_count).to eq 2
      delivery_details_1, _properties, _content = q.pop(manual_ack: true)
      delivery_details_2, _properties, _content = q.pop(manual_ack: true)

      ch.basic_ack(delivery_details_2.delivery_tag.to_i)
      ch.close

      ch = connection.create_channel
      q  = ch.queue("bunny.basic.ack.manual-acks", exclusive: true)
      expect(q.message_count).to eq 1
      ch.close
    end
  end
end
