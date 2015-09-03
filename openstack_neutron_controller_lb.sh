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

This script will install and configure the LinuxBridge agent and should only be executed on the controller node

###############################################################################################################"
echo;

if [ $1 != "auto" ]; then
   read -n1 -rsp "Press any key to continue or control-c to cancel..." key
fi

# Remove LinuxBridge agent
apt-get -y remove --pugre neutron-plugin-linuxbridge-agent

# Remove OVS
apt-get -y remove --purge neutron-plugin-openvswitch-agent openvswitch-switch
apt-get clean
apt-get -y autoremove

# Install LinuxBridge (Controller Only)
apt-get -y install neutron-plugin-linuxbridge-agent

# Configure ML2 plugin
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers local,flat,vlan,vxlan
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers linuxbridge,l2population
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types vxlan,vlan
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_flat flat_networks physnet1
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vlan network_vlan_ranges physnet1:30:33
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vxlan vni_ranges 1:1000
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini linux_bridge physical_interface_mappings physnet1:eth1

# Configure Nova
crudini --set /etc/nova/nova.conf DEFAULT linuxnet_interface_driver linuxnet_interface_driver=nova.network.linux_net.LinuxBridgeInterfaceDriver

# Configure DHCP agent
crudini --set /etc/neutron/dhcp_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.BridgeInterfaceDriver

# Restart services
service neutron-plugin-linuxbridge-agent restart
service nova-api restart
service neutron-server restart
service neutron-dhcp-agent restart

echo;
echo "##############################################################################################################

LinuxBridge agent and ML2 plugin configuration complete.

###############################################################################################################"
echo;

# End
exit
