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

# load the config.ini INI file to current BASH - quoted to preserve line breaks
eval "$(cat config.ini  | ./scripts/ini2arr.py)"

echo;
echo "##############################################################################################################

This script will install and configure the L3 agent and should only be executed on the controller node

###############################################################################################################"
echo;

if [ $1 != "auto" ]; then
   read -n1 -rsp "Press any key to continue or control-c to cancel..." key
fi

# Install L3 agent (Controller Only)
apt-get -y install neutron-l3-agent

# Configure L3 agent
if  [ $(echo ${network[vswitch]}) = "linuxbridge" ]; then
  crudini --set /etc/neutron/l3_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.BridgeInterfaceDriver
elif [ $(echo ${network[vswitch]}) = "ovs" ]; then
  crudini --set /etc/neutron/l3_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
fi

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
