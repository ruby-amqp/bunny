#!/bin/sh
server=rabbitmq-server
ctl=rabbitmqctl
delay=5

echo 'Starting a RabbitMQ node'
$server -detached

echo "Waiting for RabbitMQ to finish startup..."

$ctl await_startup --timeout 15

$ctl add_user bunny_gem bunny_password
$ctl add_user bunny_reader reader_password

$ctl add_vhost bunny_testbed

$ctl set_permissions -p / guest '.*' '.*' '.*'
$ctl set_permissions -p bunny_testbed bunny_gem '.*' '.*' '.*'
$ctl set_permissions -p bunny_testbed guest '.*' '.*' '.*'
$ctl set_permissions -p bunny_testbed bunny_reader '^---$' '^---$' '.*'

$ctl shutdown --timeout 10

echo 'Starting a RabbitMQ node in foreground (use Ctrl-C to stop)'
exec $server
