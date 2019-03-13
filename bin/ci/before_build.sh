#!/usr/bin/env sh

#!/bin/sh

#!/bin/sh

CTL=${BUNNY_RABBITMQCTL:-"sudo rabbitmqctl"}
PLUGINS=${BUNNY_RABBITMQ_PLUGINS:-"sudo rabbitmq-plugins"}

echo "Will use rabbitmqctl at ${CTL}"
echo "Will use rabbitmq-plugins at ${PLUGINS}"

$PLUGINS enable rabbitmq_management

sleep 3

# guest:guest has full access to /
$CTL add_vhost /
$CTL add_user guest guest
$CTL set_permissions -p / guest ".*" ".*" ".*"


# bunny_gem:bunny_password has full access to bunny_testbed
$CTL add_vhost bunny_testbed
$CTL add_user bunny_gem bunny_password
$CTL set_permissions -p bunny_testbed bunny_gem ".*" ".*" ".*"


# guest:guest has full access to bunny_testbed
$CTL set_permissions -p bunny_testbed guest ".*" ".*" ".*"


# bunny_reader:reader_password has read access to bunny_testbed
$CTL add_user bunny_reader reader_password
$CTL set_permissions -p bunny_testbed bunny_reader "^---$" "^---$" ".*"

# Reduce retention policy for faster publishing of stats
$CTL eval 'supervisor2:terminate_child(rabbit_mgmt_sup_sup, rabbit_mgmt_sup), application:set_env(rabbitmq_management,       sample_retention_policies, [{global, [{605, 1}]}, {basic, [{605, 1}]}, {detailed, [{10, 1}]}]), rabbit_mgmt_sup_sup:start_child().' || true
$CTL eval  'supervisor2:terminate_child(rabbit_mgmt_agent_sup_sup, rabbit_mgmt_agent_sup), application:set_env(rabbitmq_management_agent, sample_retention_policies, [{global, [{605, 1}]}, {basic, [{605, 1}]}, {detailed, [{10, 1}]}]), rabbit_mgmt_agent_sup_sup:start_child().' || true
