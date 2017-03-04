require "spec_helper"

unless ENV["CI"]
  describe "Rapidly opening and closing lots of channels on a non-threaded connection" do
    before :all do
      @connection = Bunny.new(username: "bunny_gem", password: "bunny_password", vhost: "bunny_testbed",
        automatic_recovery: false, threaded: false)
      @connection.start
    end

    after :all do
      @connection.close
    end

    context "in a single-threaded scenario" do
      let(:n) { 500 }

      it "works correctly" do
        xs = Array.new(n) { @connection.create_channel }

        expect(xs.size).to eq n
        xs.each do |ch|
          ch.close
        end
      end
    end
  end
end
