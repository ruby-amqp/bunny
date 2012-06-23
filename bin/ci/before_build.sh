#!/bin/sh

# guest:guest has full access to /

sudo rabbitmqctl add_vhost /
sudo rabbitmqctl add_user guest guest
sudo rabbitmqctl set_permissions -p / guest ".*" ".*" ".*"


# bunny_gem:bunny_password has full access to bunny_testbed

sudo rabbitmqctl add_vhost bunny_testbed
sudo rabbitmqctl add_user bunny_gem bunny_password
sudo rabbitmqctl set_permissions -p bunny_testbed bunny_gem ".*" ".*" ".*"


# bunny_reader:reader_password has read access to bunny_testbed

sudo rabbitmqctl add_user bunny_reader reader_password
sudo rabbitmqctl clear_permissions -p bunny_testbed guest
sudo rabbitmqctl set_permissions -p bunny_testbed bunny_reader "^---$" "^---$" ".*"
