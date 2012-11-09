require "spec_helper"

describe Bunny::Queue, "#delete" do
  let(:connection) do
    c = Bunny.new
    c.start
    c
  end


  context "with a name of an existing queue" do
    it "deletes that queue" do
      ch = connection.create_channel
      q  = ch.queue("")

      puts(q.delete)
      expect {
        q.delete
      }.to raise_error(Bunny::NotFound)

      ch.close
    end
  end
end
