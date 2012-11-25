require "spec_helper"

describe Bunny::Exchange, "#publish" do
  let(:connection) do
    c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed")
    c.start
    c
  end

  after :all do
    connection.close if connection.open?
  end


  context "with all default delivery and message properties" do
    it "routes messages to a queue with the same name as the routing key" do
      ch = connection.create_channel
      x  = ch.default_exchange

      returned = []
      x.on_return do |basic_deliver, properties, content|
        returned << content
      end
      
      x.publish("xyzzy", :routing_key => rand.to_s, :mandatory => true)
      sleep 0.5

      returned.should include("xyzzy")

      ch.close
    end
  end
end
