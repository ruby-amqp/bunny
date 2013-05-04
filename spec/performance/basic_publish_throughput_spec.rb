# -*- coding: utf-8 -*-
require "spec_helper"

unless ENV["CI"]
  require "benchmark"

  # These are rough numbers and will vary between hardware, Ruby implementations,
  # etc. They are supposed to catch most obvious regressions. MK.
  describe "basic.publish throughput" do
    let(:connection) do
      c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed")
      c.start
      c
    end

    before :all do
      c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed")
      c.start
      ch = c.create_channel
      x  = ch.default_exchange

      # warmup run
      20_000.times do
        x.publish("a")
      end
    end

    context "with messages 128 bytes in size" do
      let(:n) { 30_000 }
      let(:y) { 128 }

      it "should be no lower than 5 KHz" do
        ch = connection.create_channel
        x  = ch.default_exchange
        s  = "z" * y

        result = Benchmark.realtime {
          n.times do
            x.publish(s, :routing_key => "anything")
          end
        }
        # puts "Publishing #{n} messages of #{y} bytes took #{result} s"
        result.should be < 6.0
      end
    end

    context "with messages 512 bytes in size" do
      let(:n) { 30_000 }
      let(:y) { 512 }

      it "should be no lower than 5 KHz" do
        ch = connection.create_channel
        x  = ch.default_exchange
        s  = "z" * y

        result = Benchmark.realtime {
          n.times do
            x.publish(s, :routing_key => "anything")
          end
        }
        # puts "Publishing #{n} messages of #{y} bytes took #{result} s"
        result.should be < 6.0
      end
    end

    context "with messages 1 KB in size" do
      let(:n) { 30_000 }
      let(:y) { 1024 }

      it "should be no lower than 5 KHz" do
        ch = connection.create_channel
        x  = ch.default_exchange
        s  = "z" * y

        result = Benchmark.realtime {
          n.times do
            x.publish(s, :routing_key => "anything")
          end
        }
        # puts "Publishing #{n} messages of #{y} bytes took #{result} s"
        result.should be < 6.0
      end
    end

    context "with messages 4 KB in size" do
      let(:n) { 30_000 }
      let(:y) { 4 * 1024 }

      it "should be no lower than 5 KHz" do
        ch = connection.create_channel
        x  = ch.default_exchange
        s  = "z" * y

        result = Benchmark.realtime {
          n.times do
            x.publish(s, :routing_key => "anything")
          end
        }
        # puts "Publishing #{n} messages of #{y} bytes took #{result} s"
        result.should be < 6.0
      end
    end

    context "with messages 128K bytes in size" do
      let(:n) { 30_000 }
      let(:y) { 128 * 1024 }

      it "should be no lower than 1.2 KHz" do
        ch = connection.create_channel
        x  = ch.default_exchange
        s  = "z" * y

        result = Benchmark.realtime {
          n.times do
            x.publish(s, :routing_key => "anything")
          end
        }
        # puts "Publishing #{n} messages of #{y} bytes took #{result} s"
        result.should be < 25
      end
    end
  end
end
