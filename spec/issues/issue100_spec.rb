require "spec_helper"

unless ENV["CI"]
  describe Bunny::Channel, "#basic_publish" do
    let(:connection) do
      c = Bunny.new(:user     => "bunny_gem",
                    :password => "bunny_password",
                    :vhost    => "bunny_testbed",
                    :socket_timeout => 0)
      c.start
      c
    end

    after :all do
      connection.close if connection.open?
    end


    context "when publishing thousands of messages" do
      let(:n) { 2_000 }
      let(:m) { 10 }

      it "successfully publishers them all" do
        ch = connection.create_channel

        q  = ch.queue("", :exclusive => true)
        x  = ch.default_exchange

        body = "x" * 1024
        m.times do |i|
          n.times do
            x.publish(body, :routing_key => q.name)
          end
          puts "Published #{i * n} 1K messages..."
        end

        q.purge
        ch.close
      end
    end
  end
end
