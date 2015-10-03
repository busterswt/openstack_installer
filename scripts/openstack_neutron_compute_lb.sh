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

This script will install and configure the LinuxBridge agent and should only be executed on the compute node

###############################################################################################################"
echo;
if [ $1 != "auto" ]; then
   read -n1 -rsp "Press any key to continue or control-c to cancel..." key
fi
# Install LinuxBridge (Compute Only)
apt-get -y install neutron-plugin-linuxbridge-agent

# Configure ML2 plugin
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers local,flat,vlan,vxlan
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers linuxbridge,l2population
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types vxlan,vlan
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_flat flat_networks physnet1
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vlan network_vlan_ranges physnet1:$(echo ${network[tenant_vlan_range]})
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vxlan vni_ranges 1:1000
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini linux_bridge physical_interface_mappings physnet1:$(echo ${network[physical_bridge_interface]})

#Grab my IP
MY_NAME=$(hostname -s)
MY_OVERLAY_IP=$MY_NAME[overlay_addr]

crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini agent enable_vxlan True
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini agent l2_population True
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini agent local_ip $(echo "${!MY_OVERLAY_IP}")

# Configure Nova
crudini --set /etc/nova/nova.conf DEFAULT linuxnet_interface_driver linuxnet_interface_driver=nova.network.linux_net.LinuxBridgeInterfaceDriver

# Restart services
service neutron-plugin-linuxbridge-agent restart
service nova-compute restart

echo;
echo "##############################################################################################################

LinuxBridge agent and ML2 plugin configuration complete.

###############################################################################################################"
echo;

# End
exit
