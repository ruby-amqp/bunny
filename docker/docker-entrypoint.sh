#!/bin/sh
server=rabbitmq-server
ctl=rabbitmqctl
plugins=rabbitmq-plugins
delay=3

echo '[Configuration] Starting RabbitMQ in detached mode.'

$server -detached

echo "[Configuration] Waiting $delay seconds for RabbitMQ to start."

sleep $delay

echo '*** Enabling plugins ***'
$plugins enable --online rabbitmq_management
$plugins enable --online rabbitmq_consistent_hash_exchange

echo '*** Creating users ***'
$ctl add_user bunny_gem bunny_password
$ctl add_user bunny_reader reader_password

echo '*** Creating virtual hosts ***'
$ctl add_vhost bunny_testbed

echo '*** Setting virtual host permissions ***'
$ctl set_permissions -p / guest '.*' '.*' '.*'
$ctl set_permissions -p bunny_testbed bunny_gem '.*' '.*' '.*'
$ctl set_permissions -p bunny_testbed guest '.*' '.*' '.*'
$ctl set_permissions -p bunny_testbed bunny_reader '^---$' '^---$' '.*'

$ctl stop

echo "[Configuration] Waiting $delay seconds for RabbitMQ to stop."

sleep $delay

echo 'Starting RabbitMQ in foreground (CTRL-C to exit)'

exec $server
