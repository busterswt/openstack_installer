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

This script will install and configure the L3 agent and should only be executed on the controller node

###############################################################################################################"
echo;

if [ $1 != "auto" ]; then
   read -n1 -rsp "Press any key to continue or control-c to cancel..." key
fi

# Remove L3 agent
apt-get -y remove --purge neutron-l3-agent
apt-get clean
apt-get -y autoremove

# Install L3 agent (Controller Only)
apt-get -y install neutron-l3-agent

# Configure L3 agent
crudini --set /etc/neutron/l3_agent.ini DEFAULT neutron.agent.linux.interface.OVSInterfaceDriver
crudini --set /etc/neutron/l3_agent.ini DEFAULT external_network_bridge

# Restart service
service neutron-l3-agent restart


echo;
echo "##############################################################################################################

L3 configuration complete.

###############################################################################################################"
echo;

# End
exit
