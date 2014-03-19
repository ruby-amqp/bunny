require "spec_helper"

describe Bunny::Session do
  let(:http_client) { RabbitMQ::HTTP::Client.new("http://127.0.0.1:15672") }

  def close_connection(client_port)
    c = http_client.
      list_connections.
      find   { |conn_info| conn_info.peer_port.to_i == client_port }

    http_client.close_connection(c.name)
  end

  def wait_for_recovery
    sleep 0.5
  end

  it "can be closed" do
    c  = Bunny.new(:automatically_recover => false)
    c.start
    ch = c.create_channel

    c.should be_connected
    c.stop
    c.should be_closed
  end

  it "can be closed twice (Session#close is idempotent)" do
    c  = Bunny.new(:automatically_recover => false)
    c.start
    ch = c.create_channel

    c.should be_connected
    c.stop
    c.should be_closed
    c.stop
    c.should be_closed
  end

  describe "in a single threaded mode" do
    it "can be closed" do
      c  = Bunny.new(:automatically_recover => false, :threaded => false)
      c.start
      ch = c.create_channel

      c.should be_connected
      c.stop
      c.should be_closed
    end
  end


  describe "that recovers from connection.close" do
    it "can be closed" do
      c  = Bunny.new(:automatically_recover => false, :recover_from_connection_close => true, :network_recovery_interval => 0.2)
      c.start
      ch = c.create_channel

      c.should be_open
      close_connection(c.local_port)
      sleep 0.2
      c.should_not be_open

      wait_for_recovery
      c.should be_open
      ch.should be_open

      c.close
    end
  end
end
