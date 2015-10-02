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

This script will install and configure Neutron (Network Service) and should only be executed on the controller node

WARNING: Any existing Neutron configuration will be lost. This includes networks, subnets, routers, etc.

###############################################################################################################"
echo;

if [ $1 != "auto" ]; then
   read -n1 -rsp "Press any key to continue or control-c to cancel..." key
fi

# Install Neutron (Compute Only)
apt-get -y install neutron-plugin-ml2

# Configure DB
crudini --set /etc/neutron/neutron.conf database connection mysql://neutron:neutron@controller01/neutron

# Configure kernel parameters
sed -i "/net.ipv4.ip_forward/c\net.ipv4.ip_forward = 1" /etc/sysctl.conf
sed -i "/net.ipv4.conf.default.rp_filter/c\net.ipv4.conf.default.rp_filter = 0" /etc/sysctl.conf
sed -i -e "\$anet.ipv4.conf.all.rp_filter = 0" /etc/sysctl.conf
sed -i -e "\$anet.bridge.bridge-nf-call-iptables=1" /etc/sysctl.conf
sed -i -e "\$anet.bridge.bridge-nf-call-ip6tables=1" /etc/sysctl.conf
sysctl -p

# Configure Neutron
crudini --set /etc/neutron/neutron.conf DEFAULT auth_strategy keystone
crudini --set /etc/neutron/neutron.conf keystone_authtoken auth_uri http://controller01:5000
crudini --set /etc/neutron/neutron.conf keystone_authtoken auth_url http://controller01:35357
crudini --set /etc/neutron/neutron.conf keystone_authtoken auth_plugin password
crudini --set /etc/neutron/neutron.conf keystone_authtoken project_domain_id default
crudini --set /etc/neutron/neutron.conf keystone_authtoken user_domain_id default
crudini --set /etc/neutron/neutron.conf keystone_authtoken project_name service
crudini --set /etc/neutron/neutron.conf keystone_authtoken username neutron
crudini --set /etc/neutron/neutron.conf keystone_authtoken password neutron
crudini --set /etc/neutron/neutron.conf DEFAULT rpc_backend rabbit
crudini --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_host controller01
crudini --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_userid openstack
crudini --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_password rabbit

# Configure Nova
crudini --set /etc/nova/nova.conf DEFAULT network_api_class nova.network.neutronv2.api.API
crudini --set /etc/nova/nova.conf neutron url http://controller01:9696

crudini --set /etc/nova/nova.conf neutron auth_strategy keystone
crudini --set /etc/nova/nova.conf neutron admin_tenant_name service
crudini --set /etc/nova/nova.conf neutron admin_username neutron
crudini --set /etc/nova/nova.conf neutron admin_password neutron
crudini --set /etc/nova/nova.conf neutron admin_auth_url http://controller01:35357/v2.0
crudini --set /etc/nova/nova.conf neutron url http://controller01:9696

crudini --set /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver

crudini --set /etc/nova/nova.conf DEFAULT security_group_api neutron

# ML2 Config
crudini --set /etc/neutron/neutron.conf DEFAULT core_plugin ml2
crudini --set /etc/neutron/neutron.conf DEFAULT service_plugins router

# Restart services
service nova-compute restart

echo;
echo "##############################################################################################################

Neutron installation is complete.

###############################################################################################################"
echo;

# End
exit
