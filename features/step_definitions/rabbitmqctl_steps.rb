#!/usr/bin/env ruby

# Cucumber step definitions for interacting with a rabbitmq server

# Find the r
$rabbitmqctl = ( ENV['RABBITMQCTL'] || which('rabbitmqctl') ) or
	abort "Can't find rabbitmqctl in your PATH. Try running with " +
	      "RABBITMQCTL=/path/to/rabbitmqctl"

Given /^a running rabbitmq server with no MUES vhosts or users$/ do
	
end

Then /^the initial vhosts are added to the rabbitmq server$/ do
	pending # express the regexp above with the code you wish you had
end

Then /^the initial users are added to the rabbitmq server$/ do
	pending # express the regexp above with the code you wish you had
end


exec erl \
    -pa "`dirname $0`/../ebin" \
    ${RABBITMQ_START_RABBIT} \
    -sname ${RABBITMQ_NODENAME} \
    -boot start_sasl \
    +W w \
    ${RABBITMQ_SERVER_ERL_ARGS} \
    -rabbit tcp_listeners '[{"'${RABBITMQ_NODE_IP_ADDRESS}'", '${RABBITMQ_NODE_PORT}'}]' \
    -sasl errlog_type error \
    -kernel error_logger '{file,"'${RABBITMQ_LOGS}'"}' \
    -sasl sasl_error_logger '{file,"'${RABBITMQ_SASL_LOGS}'"}' \
    -os_mon start_cpu_sup true \
    -os_mon start_disksup false \
    -os_mon start_memsup false \
    -os_mon start_os_sup false \
    -os_mon memsup_system_only true \
    -os_mon system_memory_high_watermark 0.95 \
    -mnesia dir "\"${RABBITMQ_MNESIA_DIR}\"" \
    ${RABBITMQ_CLUSTER_CONFIG_OPTION} \
    ${RABBITMQ_SERVER_START_ARGS} \
    "$@"
