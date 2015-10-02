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

This script will install and configure the Open vSwitch agent and should only be executed on the compute node

###############################################################################################################"
echo;
if [ $1 != "auto" ]; then
   read -n1 -rsp "Press any key to continue or control-c to cancel..." key
fi

# Install OVS (Compute Only)
apt-get -y install neutron-plugin-openvswitch-agent bridge-utils

# Configure ML2 plugin
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers local,flat,vlan,gre,vxlan
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers openvswitch,l2population
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types vlan,vxlan
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_flat flat_networks physnet1
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vlan network_vlan_ranges physnet1:$(echo ${network[tenant_vlan_range]})
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vxlan vni_ranges 1:1000
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini OVS bridge_mappings physnet1:$(echo ${network[ovs_bridge_name]})
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini agent tunnel_types vxlan

# Configure Nova
crudini --set /etc/nova/nova.conf DEFAULT linuxnet_interface_driver nova.network.linux_net.LinuxOVSInterfaceDriver

# Configure OVS Bridge
ovs-vsctl add-br $(echo ${network[ovs_bridge_name]})
ovs-vsctl add-port $(echo ${network[ovs_bridge_name]}) $(echo ${network[physical_bridge_interface]})

#Grab my IP
MY_NAME=$(hostname -s)
MY_OVERLAY_IP=$MY_NAME[overlay_addr]

# Configure OVS
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini OVS enable_tunneling true
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini OVS tunnel_type vxlan
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini OVS local_ip $(echo "${!MY_OVERLAY_IP}")

# Restart services
service neutron-plugin-openvswitch-agent restart
service nova-compute restart

echo;
echo "##############################################################################################################

OVS agent and ML2 plugin configuration complete.

###############################################################################################################"
echo;

# End
exit
