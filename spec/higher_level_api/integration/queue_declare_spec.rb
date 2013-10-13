require "spec_helper"

describe Bunny::Queue do
  let(:connection) do
    c = Bunny.new(:user => "bunny_gem", :password => "bunny_password", :vhost => "bunny_testbed")
    c.start
    c
  end

  after :each do
    connection.close if connection.open?
  end

  context "when queue name is specified" do
    let(:name) { "a queue declared at #{Time.now.to_i}" }

    it "declares a new queue with that name" do
      ch   = connection.create_channel

      q    = ch.queue(name)
      q.name.should == name

      q.delete
      ch.close
    end

    it "caches that queue" do
      ch   = connection.create_channel

      q = ch.queue(name)
      ch.queue(name).object_id.should == q.object_id

      q.delete
      ch.close
    end
  end


  context "when queue name is passed on as an empty string" do
    it "uses server-assigned queue name" do
      ch   = connection.create_channel

      q = ch.queue("")
      q.name.should_not be_empty
      q.name.should =~ /^amq.gen.+/
      q.should be_server_named
      q.delete

      ch.close
    end
  end


  context "when queue is declared as durable" do
    it "declares it as durable" do
      ch   = connection.create_channel

      q = ch.queue("bunny.tests.queues.durable", :durable => true)
      q.should be_durable
      q.should_not be_auto_delete
      q.should_not be_exclusive
      q.arguments.should be_nil
      q.delete

      ch.close
    end
  end


  context "when queue is declared as exclusive" do
    it "declares it as exclusive" do
      ch   = connection.create_channel

      q = ch.queue("bunny.tests.queues.exclusive", :exclusive => true)
      q.should be_exclusive
      q.should_not be_durable
      q.delete

      ch.close
    end
  end


  context "when queue is declared as auto-delete" do
    it "declares it as auto-delete" do
      ch   = connection.create_channel

      q = ch.queue("bunny.tests.queues.auto-delete", :auto_delete => true)
      q.should be_auto_delete
      q.should_not be_exclusive
      q.should_not be_durable
      q.delete

      ch.close
    end
  end



  context "when queue is declared with a different set of attributes" do
    it "raises an exception" do
      ch   = connection.create_channel

      q = ch.queue("bunny.tests.queues.auto-delete", :auto_delete => true, :durable => false)
      expect {
        # force re-declaration
        ch.queue_declare("bunny.tests.queues.auto-delete", :auto_delete => false, :durable => true)
      }.to raise_error(Bunny::PreconditionFailed)

      ch.should be_closed
    end
  end


  context "when queue is declared with message TTL" do
    let(:args) do
      # in ms
      {"x-message-ttl" => 1000}
    end

    it "causes all messages in it to have a TTL" do
      ch   = connection.create_channel

      q = ch.queue("bunny.tests.queues.with-arguments.ttl", :arguments => args, :exclusive => true)
      q.arguments.should == args

      q.publish("xyzzy")
      sleep 0.1

      q.message_count.should == 1
      sleep 1.5
      q.message_count.should == 0

      ch.close
    end
  end


  describe "#queue_exists?" do
    context "when a queue exists" do
      it "returns true" do
        ch = connection.create_channel
        q  = ch.queue("", :exlusive => true)

        connection.queue_exists?(q.name).should be_true
      end
    end

    context "when a queue DOES NOT exist" do
      it "returns false" do
        connection.queue_exists?("suf89u9a4jo3ndnakls##{Time.now.to_i}").should be_false
      end
    end
  end



  unless ENV["CI"]
    # requires RabbitMQ 3.1+
    context "when queue is declared with bounded length" do
      let(:n) { 10 }
      let(:args) do
        # in ms
        {"x-max-length" => n}
      end

      # see http://www.rabbitmq.com/maxlength.html for more info
      it "causes the queue to be bounded" do
        ch   = connection.create_channel

        q = ch.queue("bunny.tests.queues.with-arguments.max-length", :arguments => args, :exclusive => true)
        q.arguments.should == args

        (n * 10).times do
          q.publish("xyzzy")
        end

        q.message_count.should == n
        (n * 5).times do
          q.publish("xyzzy")
        end

        q.message_count.should == n
        q.delete

        ch.close
      end
    end
  end
end
