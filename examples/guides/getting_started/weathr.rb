#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "bunny"

STDOUT.sync = true

connection = Bunny.new
connection.start

channel  = connection.create_channel
# topic exchange name can be any string
exchange = channel.topic("weathr", :auto_delete => true)

# Subscribers.
channel.queue("", :exclusive => true).bind(exchange, :routing_key => "americas.north.#").subscribe do |delivery_info, properties, payload|
  puts "An update for North America: #{payload}, routing key is #{delivery_info.routing_key}"
end
channel.queue("americas.south").bind(exchange, :routing_key => "americas.south.#").subscribe do |delivery_info, properties, payload|
  puts "An update for South America: #{payload}, routing key is #{delivery_info.routing_key}"
end
channel.queue("us.california").bind(exchange, :routing_key => "americas.north.us.ca.*").subscribe do |delivery_info, properties, payload|
  puts "An update for US/California: #{payload}, routing key is #{delivery_info.routing_key}"
end
channel.queue("us.tx.austin").bind(exchange, :routing_key => "#.tx.austin").subscribe do |delivery_info, properties, payload|
  puts "An update for Austin, TX: #{payload}, routing key is #{delivery_info.routing_key}"
end
channel.queue("it.rome").bind(exchange, :routing_key => "europe.italy.rome").subscribe do |delivery_info, properties, payload|
  puts "An update for Rome, Italy: #{payload}, routing key is #{delivery_info.routing_key}"
end
channel.queue("asia.hk").bind(exchange, :routing_key => "asia.southeast.hk.#").subscribe do |delivery_info, properties, payload|
  puts "An update for Hong Kong: #{payload}, routing key is #{delivery_info.routing_key}"
end

exchange.publish("San Diego update", :routing_key => "americas.north.us.ca.sandiego").
  publish("Berkeley update",         :routing_key => "americas.north.us.ca.berkeley").
  publish("San Francisco update",    :routing_key => "americas.north.us.ca.sanfrancisco").
  publish("New York update",         :routing_key => "americas.north.us.ny.newyork").
  publish("São Paolo update",        :routing_key => "americas.south.brazil.saopaolo").
  publish("Hong Kong update",        :routing_key => "asia.southeast.hk.hongkong").
  publish("Kyoto update",            :routing_key => "asia.southeast.japan.kyoto").
  publish("Shanghai update",         :routing_key => "asia.southeast.prc.shanghai").
  publish("Rome update",             :routing_key => "europe.italy.roma").
  publish("Paris update",            :routing_key => "europe.france.paris")

sleep 1.0

connection.close
