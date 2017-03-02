# -*- coding: utf-8 -*-
require 'spec_helper'

describe Bunny::Session do
  let(:connection) do
    c = Bunny.new(
        user: 'bunny_gem', password: 'bunny_password',
        vhost: 'bunny_testbed',
        port: ENV.fetch('RABBITMQ_PORT', 5672)
    )
    c.start
    c
  end

  context 'after the connection has been manually closed' do
    before :each do
      connection.close
    end

    after :each do
      connection.close if connection.open?
    end

    describe '#create_channel' do
      it 'should raise an exception' do
        expect {
          connection.create_channel
        }.to raise_error(Bunny::ConnectionAlreadyClosed)
      end
    end
  end
end
