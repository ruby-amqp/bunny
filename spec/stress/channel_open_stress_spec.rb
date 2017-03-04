require "spec_helper"

describe "Rapidly opening and closing lots of channels" do
  before :all do
    @connection = Bunny.new(automatic_recovery: false).tap do |c|
      c.start
    end
  end

  after :all do
    @connection.close
  end

  context "in a single-threaded scenario" do
    let(:n) { 500 }

    it "works correctly" do
      xs = Array.new(n) { @connection.create_channel }
      puts "Opened #{n} channels"

      expect(xs.size).to eq n
      xs.each do |ch|
        ch.close
      end
    end
  end

  100.times do |i|
    context "in a multi-threaded scenario A (take #{i})" do
      # actually, on MRI values greater than ~100 will eventually cause write
      # operations to fail with a timeout (1 second is not enough)
      # which will cause recovery to re-acquire @channel_mutex in Session.
      # Because Ruby's mutexes are not re-entrant, it will raise a ThreadError.
      #
      # But this already demonstrates that within these platform constraints,
      # Bunny is safe to use in such scenarios.
      let(:n) { 20 }

      it "works correctly" do
        ts = []

        n.times do
          t = Thread.new do
            ch1 = @connection.create_channel
            q   = ch1.queue("", exclusive: true)
            q.delete
            ch1.close

            ch2 = @connection.create_channel
            ch2.close
          end
          t.abort_on_exception = true
          ts << t
        end

        ts.each { |t| t.join }
      end
    end
  end

  100.times do |i|
    context "in a multi-threaded scenario B (take #{i})" do
      let(:n) { 20 }

      it "works correctly" do
        ts = []

        n.times do
          t = Thread.new do
            3.times do
              ch = @connection.create_channel
              x  = ch.topic('bunny.stress.topics.t2', durable: false)
              ch.close
            end
          end
          t.abort_on_exception = true
          ts << t
        end

        ts.each { |t| t.join }
      end
    end
  end
end
