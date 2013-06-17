require "spec_helper"

unless ENV["CI"]
  describe "Rapidly opening and closing lots of channels on a non-threaded connection" do
    let(:connection) do
      c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed", :automatic_recovery => false, :threaded => false)
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

        xs.size.should == n
        xs.each do |ch|
          ch.close
        end
      end
    end
  end
end
