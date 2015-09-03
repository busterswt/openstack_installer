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

This script will install and configure the Open vSwitch agent and should only be executed on the controller node

###############################################################################################################"
echo;
read -n1 -rsp "Press any key to continue or control-c to cancel..." key

# Remove LinuxBridge agent
apt-get -y remove --pure neutron-plugin-linuxbridge-agent

# Remove OVS
apt-get -y remove --purge neutron-plugin-openvswitch-agent openvswitch-switch
apt-get clean
apt-get -y autoremove

# Install OVS (Controller Only)
apt-get -y install neutron-plugin-openvswitch-agent

# Configure ML2 plugin
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers local,flat,vlan,gre,vxlan
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers openvswitch,l2population
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types vlan,vxlan
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_flat flat_networks physnet1
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vlan network_vlan_ranges physnet1:30:33
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vxlan vni_ranges 1:1000
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini OVS bridge_mappings physnet1:br-eth1
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini agent tunnel_types vxlan

# Configure Nova
crudini --set /etc/nova/nova.conf DEFAULT linuxnet_interface_driver nova.network.linux_net.LinuxOVSInterfaceDriver

# Configure DHCP agent
crudini --set /etc/neutron/dhcp_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver

# Configure OVS Bridge
ovs-vsctl add-br br-eth1
ovs-vsctl add-port br-eth1 eth1

# Configure OVS
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini OVS enable_tunneling true
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini OVS tunnel_type vxlan
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini OVS local_ip 172.18.0.100

# Restart services
service neutron-plugin-openvswitch-agent restart
service nova-api restart
service neutron-server restart
service neutron-dhcp-agent restart

echo;
echo "##############################################################################################################

OVS agent and ML2 plugin configuration complete.

###############################################################################################################"
echo;

# End
exit
