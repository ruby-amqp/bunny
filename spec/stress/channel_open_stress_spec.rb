require "spec_helper"

unless ENV["CI"]
  describe "Rapidly opening and closing lots of channels" do
    let(:connection) do
      c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed", :automatic_recovery => false)
      c.start
      c
    end

    after :all do
      connection.close
    end

    context "in a single-threaded scenario" do
      let(:n) { 500 }

      it "works correctly" do
        xs = Array.new(n) { connection.create_channel }
        puts "Opened #{n} channels"

        xs.size.should == n
        xs.each do |ch|
          ch.close
        end
      end
    end

    context "in a multi-threaded scenario" do
      # actually, on MRI values greater than ~100 will eventually cause write
      # operations to fail with a timeout (1 second is not enough)
      # which will cause recovery to re-acquire @channel_mutex in Session.
      # Because Ruby's mutexes are not re-entrant, it will raise a ThreadError.
      #
      # But this already demonstrates that within these platform constraints,
      # Bunny is safe to use in such scenarios.
      let(:n) { 50 }

      it "works correctly" do
        n.times do
          t = Thread.new do
            ch = connection.create_channel

            ch.close
          end
          t.abort_on_exception = true
        end
      end
    end
  end
end
