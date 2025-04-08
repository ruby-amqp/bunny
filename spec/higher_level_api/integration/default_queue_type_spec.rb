require "spec_helper"

describe Bunny::Queue do
  %w(classic quorum stream).each do |qtype|
    context "when target virtual host's default queue type is '#{qtype}'" do
      let(:connection) do
        # see bin/ci/before_build
        c = Bunny.new(user: "bunny_gem", password: "bunny_password", vhost: "bunny_dqt_#{qtype}")
        c.start
        c
      end
  
      after :each do
        connection.close if connection.open?
      end
  
      let(:name) { "bunny.dqt.#{qtype}.#{rand}" }
      let(:x_args) do
        {"x-queue-type" => qtype}
      end
  
      context "and x-queue-type is omitted by the client" do
        it "declares a new queue with that name" do
          ch   = connection.create_channel

          q    = ch.queue(name, durable: true, exclusive: false)
          expect(q.name).to eq name

          q.delete
          ch.close
        end

        it "can re-declare the queue" do
          ch   = connection.create_channel

          # this lower-level API bypasses queue object cache
          50.times do
            ch.queue_declare(name, durable: true, exclusive: false)
          end
          expect(ch).to be_open
  
          ch.queue_delete(name)
          ch.close
        end
      end

      context "and x-queue-type is explicitly set by the client" do
        it "declares a new queue with that name" do
          ch   = connection.create_channel

          q    = ch.queue(name, durable: true, exclusive: false, arguments: x_args)
          expect(q.name).to eq name

          q.delete
          ch.close
        end

        it "can re-declare the queue" do
          ch   = connection.create_channel

          # this lower-level API bypasses queue object cache
          50.times do
            ch.queue_declare(name, durable: true, exclusive: false, arguments: x_args)
          end
          expect(ch).to be_open

          ch.queue_delete(name)
          ch.close
        end
      end
    end
  end
end