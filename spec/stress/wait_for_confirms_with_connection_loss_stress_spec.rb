require "spec_helper"

unless ENV["CI"]
  describe "Publisher with wait_for_confirms suffering a lost connection" do
    before :all do
      @connection = Bunny.new(
        :user => "bunny_gem",
        :password => "bunny_password",
        :vhost => "bunny_testbed",
        :recover_from_connection_close => true,
        :network_recovery_interval => 0.2,
        :recovery_attempts => 3,
        :continuation_timeout => 3_000)
      @connection.start
    end

    after :all do
      @connection.close
    end

    let(:rate)        { 50 }
    let(:inner_rate)  { 5 }
    let(:max_retries) { 3 }
    let(:routing_key) { 'confirms' }

    let(:http_client) { RabbitMQ::HTTP::Client.new('http://127.0.0.1:15672') }

    let!(:ch_pub) { @connection.create_channel.tap { |ch| ch.confirm_select } }
    let!(:ch_sub) { @connection.create_channel }
    let!(:topic) { 'bunny.stress.concurrent.confirms.topic' }
    let!(:x) { ch_pub.topic(topic, :durable => true) }
    let!(:q) do
      ch_sub.queue('', :durable => true).tap do |q|
        q.bind(x.name, :routing_key => routing_key)
        q.purge
      end
    end

    def close_all_connections!
      http_client.list_connections.each do |conn_info|
        begin
          http_client.close_connection(conn_info.name)
        rescue Bunny::ConnectionForced => e
          # This is not a problem, but the specs intermittently believe it is.
          printf "Rescued forced connection: #{e.inspect}\n"
        end
      end
    end

    def wait_for_recovery
      sleep 1.5
    end

    after do
      unless ch_sub.closed?
        q.delete
        ch_sub.close
      end
      ch_pub.close unless ch_pub.closed?
    end

    it "successfully publish and consume all messages" do
      begin
        subscriber_mutex = Mutex.new
        ids_received = Set.new
        message_count = nil

        sub = Thread.new do
          begin
            q.subscribe do |delivery_info, meta, payload|
              subscriber_mutex.synchronize do
                ids_received << payload.to_i
                message_count = q.message_count
              end
            end
          end
        end
        sub.abort_on_exception = true

        pub = Thread.new do
          rate.times do |i|
            retries = 0
            begin
              inner_rate.times do |j|
                id = i * inner_rate + j
                x.publish(id.to_s, :routing_key => routing_key)
              end
              until ch_pub.unconfirmed_set.empty?
                unless ch_pub.wait_for_confirms
                  raise "Not all messages acknowledged, nacks: #{ch_pub.nacked_set.inspect}"
                end
              end
            rescue => e
              puts "Rescued error in iteration #{i}: #{e.inspect}"
              retries += 1
              raise if retries > max_retries

              puts "sleeping before retry #{retries}"
              sleep 0.5
              retry
            end
          end
          puts "Published #{rate * inner_rate} messages..."
        end
        pub.abort_on_exception = true
        sleep 0.2 while ids_received.size < 10

        close_all_connections!
        wait_for_recovery

        pub.join

        sleep 0.1 until message_count == 0
        puts "Drained queue, winding down..."

        q.delete
        ch_pub.close
        ch_sub.close
        sub.kill

        expect(ch_pub.unconfirmed_set).to be_empty

        expected_ids = Set.new((rate * inner_rate).times)
        missing_ids = expected_ids - ids_received
        expect(missing_ids).to eq(Set.new)
      ensure
        sub.kill
      end
    end
  end
end
