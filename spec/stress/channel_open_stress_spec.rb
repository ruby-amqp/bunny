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

    context "in a multi-threaded scenario A" do
      # actually, on MRI values greater than ~100 will eventually cause write
      # operations to fail with a timeout (1 second is not enough)
      # which will cause recovery to re-acquire @channel_mutex in Session.
      # Because Ruby's mutexes are not re-entrant, it will raise a ThreadError.
      #
      # But this already demonstrates that within these platform constraints,
      # Bunny is safe to use in such scenarios.
      let(:n) { 20 }

      100.times do |i|
        it "works correctly (take #{i})" do
          c = Bunny.new(:automatic_recovery => false)
          c.start
          c
          n.times do
            t = Thread.new do
              ch1 = c.create_channel
              ch1.close

              ch2 = c.create_channel
              ch2.close
            end
            t.abort_on_exception = true
          end
        end
      end
    end

    context "in a multi-threaded scenario B" do
      let(:n) { 100 }

      10.times do |i|
        it "works correctly (take #{i})" do
          c = Bunny.new(:automatic_recovery => false)
          c.start
          c

          ts = []

          n.times do
            t = Thread.new do
              10.times do
                ch = c.create_channel
                x  = ch.topic('bunny.stress.topics.t1', :durable => true)
                ch.close
              end
            end
            t.abort_on_exception = true
            ts << t
          end

          ts.each do |t|
            t.join
          end
        end
      end
    end
  end
end
