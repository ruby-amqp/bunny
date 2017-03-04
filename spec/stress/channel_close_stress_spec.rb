require "spec_helper"

describe "Rapidly closing lots of temporary channels" do
  before :all do
    @connection = Bunny.new(automatic_recovery: false).tap do |c|
      c.start
    end
  end

  after :all do
    @connection.close
  end

  100.times do |i|
    context "in a multi-threaded scenario A (take #{i})" do
      let(:n) { 20 }

      it "works correctly" do
        ts = []

        n.times do
          t = Thread.new do
            @connection.with_channel do |ch1|
              q   = ch1.queue("", exclusive: true)
              q.delete
              ch1.close
            end

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
              @connection.with_channel do |ch|
                x  = ch.topic('bunny.stress.topics.t2', durable: false)
              end
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
