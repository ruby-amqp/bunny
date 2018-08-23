require "spec_helper"
require_relative "../../toxiproxy_helper"

if ::Toxiproxy.running?
  describe Bunny::Channel, "#basic_publish" do
    include RabbitMQ::Toxiproxy


    after :each do
      @connection.close if @connection.open?
    end

    context "when the the connection detects missed heartbeat with automatic recovery" do
      before(:each) do
        setup_toxiproxy
        @connection = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed",
          host: "localhost:11111", heartbeat_timeout: 1, automatically_recover: true)
        @connection.start
      end

      let(:queue_name) { "bunny.basic.publish.queue#{rand}" }

      it "raises a ConnectionClosedError" do
        ch = @connection.create_channel
        begin
          rabbitmq_toxiproxy.down do
            sleep 2
            expect { ch.default_exchange.publish("", :routing_key => queue_name) }.to raise_error(Bunny::ConnectionClosedError)
          end
        ensure
          cleanup_toxiproxy
        end
      end

      context "when the the connection detects missed heartbeats without automatic recovery" do
        before(:each) do
          setup_toxiproxy
          @connection = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed",
            host: "localhost:11111", heartbeat_timeout: 1, automatically_recover: false, threaded: false)
          @connection.start
        end

        it "does not raise an exception on session thread" do
         rabbitmq_toxiproxy.down do
            sleep 5
          end
        end
      end
    end
  end
else
  puts "Toxiproxy isn't running, some examples will be skipped"
end
