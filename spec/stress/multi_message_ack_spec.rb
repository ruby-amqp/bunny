require "spec_helper"

unless ENV["CI"]
  describe "Subscription acknowledging multi-messages" do
    before :all do
      @connection = Bunny.new(username: "bunny_gem", password: "bunny_password",
        vhost: "bunny_testbed", automatically_recover: false)
      @connection.start
    end

    let(:max_messages) { 100_000 }

    it "successfully completes" do
      body = "."

      ch = @connection.create_channel
      ch.confirm_select

      q = ch.quorum_queue("multi-messages")

      m = Mutex.new
      acks = 0
      pubs = 0
      last = Bunny::Timestamp.now

      q.subscribe(manual_ack: true) do |delivery_info, _, _|
        sleep(0) if rand < 0.01
        ch.ack(delivery_info.delivery_tag)

        m.synchronize do
          acks += 1
          now = Bunny::Timestamp.now
          if now - last > 0.5
            puts "Ack multi-message: acks=#{acks} pubs=#{pubs}"
            last = now
          end
        end
      end

      (1..max_messages).each do
        q.publish(".")
        m.synchronize { pubs += 1 }
      end

      sleep 0.1 while m.synchronize { acks < pubs }
    end
  end
end
