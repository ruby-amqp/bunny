require "spec_helper"

unless ENV["CI"]
  describe Bunny::Queue, "#subscribe" do
    before :all do
      @connection1 = Bunny.new(:user => "bunny_gem", password:  "bunny_password", :vhost => "bunny_testbed")
      @connection1.start
      @connection2 = Bunny.new(:user => "bunny_gem", password:  "bunny_password", :vhost => "bunny_testbed")
      @connection2.start
    end

    after :all do
      [@connection1, @connection2].select { |c| !!c }.each do |c|
        c.close if c.open?
      end
    end


    context "with an empty queue" do
      it "consumes messages" do
        delivered_data = []

        ch1 = @connection1.create_channel
        ch2 = @connection1.create_channel

        q   = ch1.queue("", exclusive: true)
        q.subscribe(manual_ack: false, block: false) do |delivery_info, properties, payload|
          delivered_data << payload
        end
        sleep 0.5

        x = ch2.default_exchange
        x.publish("abc", routing_key:  q.name)
        sleep 0.7

        expect(delivered_data).to eq ["abc"]

        ch1.close
        ch2.close
      end
    end

    context "with a non-empty queue" do
      let(:queue_name) { "queue#{rand}" }

      it "consumes messages" do
        delivered_data = []

        ch1 = @connection1.create_channel
        ch2 = @connection1.create_channel

        q   = ch1.queue(queue_name, exclusive: true)
        x = ch2.default_exchange
        3.times do |i|
          x.publish("data#{i}", routing_key:  queue_name)
        end
        sleep 0.7
        expect(q.message_count).to eq 3

        q.subscribe(manual_ack: false, block: false) do |delivery_info, properties, payload|
          delivered_data << payload
        end
        sleep 0.7

        expect(delivered_data).to eq ["data0", "data1", "data2"]

        ch1.close
        ch2.close
      end
    end
  end
end
