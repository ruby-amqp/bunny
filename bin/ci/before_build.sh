#!/usr/bin/env sh

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

#
# Virtual hosts
#

# a general purpose virtual host
$CTL add_vhost bunny_testbed

# these are used for testing default queue type (DQT)
$CTL add_vhost bunny_dqt_classic --default-queue-type "classic"
$CTL add_vhost bunny_dqt_quorum --default-queue-type "quorum"
$CTL add_vhost bunny_dqt_stream --default-queue-type "stream"

#
# Users
#

$CTL add_user bunny_gem bunny_password
# used for testing certain permissions
$CTL add_user bunny_reader reader_password

#
# Permissions
#

# bunny_gem:bunny_password has full access to bunny_testbed
$CTL set_permissions -p bunny_testbed bunny_gem ".*" ".*" ".*"

# bunny_gem:bunny_password has full access to bunny_dqt_quorum
$CTL set_permissions -p bunny_dqt_classic bunny_gem ".*" ".*" ".*"
$CTL set_permissions -p bunny_dqt_quorum  bunny_gem ".*" ".*" ".*"
$CTL set_permissions -p bunny_dqt_stream  bunny_gem ".*" ".*" ".*"

$CTL set_permissions -p bunny_dqt_classic guest ".*" ".*" ".*"
$CTL set_permissions -p bunny_dqt_quorum  guest ".*" ".*" ".*"
$CTL set_permissions -p bunny_dqt_stream  guest ".*" ".*" ".*"

$CTL add_user bunny_gem bunny_password
$CTL set_permissions -p bunny_testbed bunny_gem ".*" ".*" ".*"

# guest:guest has full access to bunny_testbed
$CTL set_permissions -p bunny_testbed guest ".*" ".*" ".*"

# bunny_reader:reader_password has read access to bunny_testbed
$CTL set_permissions -p bunny_testbed bunny_reader "^---$" "^---$" ".*"

# Reduce retention policy for faster publishing of stats
$CTL eval 'supervisor2:terminate_child(rabbit_mgmt_sup_sup, rabbit_mgmt_sup), application:set_env(rabbitmq_management,       sample_retention_policies, [{global, [{605, 1}]}, {basic, [{605, 1}]}, {detailed, [{10, 1}]}]), rabbit_mgmt_sup_sup:start_child().' || true
$CTL eval  'supervisor2:terminate_child(rabbit_mgmt_agent_sup_sup, rabbit_mgmt_agent_sup), application:set_env(rabbitmq_management_agent, sample_retention_policies, [{global, [{605, 1}]}, {basic, [{605, 1}]}, {detailed, [{10, 1}]}]), rabbit_mgmt_agent_sup_sup:start_child().' || true
