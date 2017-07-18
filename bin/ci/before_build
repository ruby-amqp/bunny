#!/usr/bin/env ruby

$ctl      = ENV["BUNNY_RABBITMQCTL"]      || ENV["RABBITMQCTL"]      || "sudo rabbitmqctl"
$plugins  = ENV["BUNNY_RABBITMQ_PLUGINS"] || ENV["RABBITMQ_PLUGINS"] || "sudo rabbitmq-plugins"

def rabbit_control(args)
  command = "#{$ctl} #{args}"
  system command
end

def rabbit_plugins(args)
  command = "#{$plugins} #{args}"
  system command
end


# guest:guest has full access to /

rabbit_control 'add_vhost /'
rabbit_control 'add_user guest guest'
rabbit_control 'set_permissions -p / guest ".*" ".*" ".*"'


# bunny_gem:bunny_password has full access to bunny_testbed

rabbit_control 'add_vhost bunny_testbed'
rabbit_control 'add_user bunny_gem bunny_password'
rabbit_control 'set_permissions -p bunny_testbed bunny_gem ".*" ".*" ".*"'


# guest:guest has full access to bunny_testbed

rabbit_control 'set_permissions -p bunny_testbed guest ".*" ".*" ".*"'


# bunny_reader:reader_password has read access to bunny_testbed

rabbit_control 'add_user bunny_reader reader_password'
rabbit_control 'set_permissions -p bunny_testbed bunny_reader "^---$" "^---$" ".*"'

# requires RabbitMQ 3.0+
# rabbit_plugins 'enable rabbitmq_management'

# Reduce retention policy for faster publishing of stats
rabbit_control "eval 'supervisor2:terminate_child(rabbit_mgmt_sup_sup, rabbit_mgmt_sup), application:set_env(rabbitmq_management,       sample_retention_policies, [{global, [{605, 1}]}, {basic, [{605, 1}]}, {detailed, [{10, 1}]}]), rabbit_mgmt_sup_sup:start_child().'"
rabbit_control "eval 'supervisor2:terminate_child(rabbit_mgmt_agent_sup_sup, rabbit_mgmt_agent_sup), application:set_env(rabbitmq_management_agent, sample_retention_policies, [{global, [{605, 1}]}, {basic, [{605, 1}]}, {detailed, [{10, 1}]}]), rabbit_mgmt_agent_sup_sup:start_child().'"
