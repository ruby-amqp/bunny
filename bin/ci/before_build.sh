#!/bin/sh

${RABBITMQCTL:="sudo rabbitmqctl"}
${RABBITMQ_PLUGINS:="sudo rabbitmq-plugins"}

# guest:guest has full access to /

$RABBITMQCTL add_vhost /
$RABBITMQCTL add_user guest guest
$RABBITMQCTL set_permissions -p / guest ".*" ".*" ".*"


# bunny_gem:bunny_password has full access to bunny_testbed

$RABBITMQCTL add_vhost bunny_testbed
$RABBITMQCTL add_user bunny_gem bunny_password
$RABBITMQCTL set_permissions -p bunny_testbed bunny_gem ".*" ".*" ".*"


# guest:guest has full access to bunny_testbed

$RABBITMQCTL set_permissions -p bunny_testbed guest ".*" ".*" ".*"


# bunny_reader:reader_password has read access to bunny_testbed

$RABBITMQCTL add_user bunny_reader reader_password
$RABBITMQCTL set_permissions -p bunny_testbed bunny_reader "^---$" "^---$" ".*"

# requires RabbitMQ 3.0+
# $RABBITMQ_PLUGINS enable rabbitmq_consistent_hash_exchange
