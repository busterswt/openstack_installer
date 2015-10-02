#!/bin/bash

function cleanup {
   reset
   exit
}
trap cleanup SIGHUP SIGINT SIGTERM

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "You must be 'root' to execute this script" 1>&2
   exit 1
fi

echo;
echo "##############################################################################################################

This script will install and configure RabbitMQ and should only be executed on the controller node

###############################################################################################################"
echo;

if [ $1 != "auto" ]; then
   read -n1 -rsp "Press any key to continue or control-c to cancel..." key
fi

# Install RabbutMQ
apt-get -y install rabbitmq-server

# Configure RabbitMQ
rabbitmqctl add_user openstack rabbit
rabbitmqctl set_permissions openstack ".*" ".*" ".*"

# End
exit
