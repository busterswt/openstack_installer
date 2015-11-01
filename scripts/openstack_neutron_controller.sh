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

This script will install and configure Neutron (Network Service) and should only be executed on the controller node

WARNING: Any existing Neutron configuration will be lost. This includes networks, subnets, routers, etc.

###############################################################################################################"
echo;

if [ $1 != "auto" ]; then
   read -n1 -rsp "Press any key to continue or control-c to cancel..." key
fi

# Install Neutron (Controller Only)
apt-get -y install neutron-server neutron-common neutron-dhcp-agent neutron-metadata-agent neutron-plugin-ml2 python-neutronclient neutron-plugin-ml2

# Configure DB

mysql -u root -popenstack -e "DROP DATABASE neutron;";
mysql -u root -popenstack -e "CREATE DATABASE neutron;";
mysql -u root -popenstack -e "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY 'neutron';"
mysql -u root -popenstack -e "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY 'neutron';"
crudini --set /etc/neutron/neutron.conf database connection mysql://neutron:neutron@controller01/neutron

# Configure Endpoints
source ~/adminrc
openstack user create --domain default --password neutron neutron
openstack role add --project service --user neutron admin

openstack service create --name neutron \
--description "OpenStack Networking" network

openstack endpoint create --region RegionOne \
  network public http://controller01:9696
openstack endpoint create --region RegionOne \
  network internal http://controller01:9696
openstack endpoint create --region RegionOne \
  network admin http://controller01:9696

# Configure kernel parameters
sed -i "/net.ipv4.ip_forward/c\net.ipv4.ip_forward = 1" /etc/sysctl.conf
sed -i "/net.ipv4.conf.default.rp_filter/c\net.ipv4.conf.default.rp_filter = 0" /etc/sysctl.conf
sed -i -e "\$anet.ipv4.conf.all.rp_filter = 0" /etc/sysctl.conf
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

crudini --set /etc/neutron/neutron.conf DEFAULT bind_host $(echo ${controller01[mgmt_addr]})

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

crudini --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_status_changes True
crudini --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_data_changes True
crudini --set /etc/neutron/neutron.conf DEFAULT nova_url http://controller01:8774/v2

crudini --set /etc/neutron/neutron.conf nova auth_url http://controller01:35357
crudini --set /etc/neutron/neutron.conf nova auth_plugin password
crudini --set /etc/neutron/neutron.conf nova project_domain_id default
crudini --set /etc/neutron/neutron.conf nova user_domain_id default
crudini --set /etc/neutron/neutron.conf nova region_name RegionOne
crudini --set /etc/neutron/neutron.conf nova project_name service
crudini --set /etc/neutron/neutron.conf nova username nova
crudini --set /etc/neutron/neutron.conf nova password nova

# ML2 Config
crudini --set /etc/neutron/neutron.conf DEFAULT core_plugin ml2
crudini --set /etc/neutron/neutron.conf DEFAULT service_plugins router

# Sync DB
su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron

# Restart services
service nova-api restart
service nova-scheduler restart
service nova-conductor restart
service neutron-server restart

# Configure DHCP
crudini --set /etc/neutron/dhcp_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.BridgeInterfaceDriver
crudini --set /etc/neutron/dhcp_agent.ini DEFAULT enable_isolated_metadata True
crudini --set /etc/neutron/dhcp_agent.ini DEFAULT dhcp_domain learningneutron.com
crudini --set /etc/neutron/dhcp_agent.ini DEFAULT dhcp_delete_namespaces true
service neutron-dhcp-agent restart

# Configure Metadata
METADATA_SECRET=insecuresecret123

crudini --set /etc/nova/nova.conf neutron metadata_proxy_shared_secret $METADATA_SECRET
crudini --set /etc/nova/nova.conf neutron service_metadata_proxy true

crudini --set /etc/neutron/metadata_agent.ini DEFAULT auth_uri http://controller01:5000
crudini --set /etc/neutron/metadata_agent.ini DEFAULT auth_url http://controller01:35357
crudini --set /etc/neutron/metadata_agent.ini DEFAULT auth_region RegionOne
crudini --set /etc/neutron/metadata_agent.ini DEFAULT auth_plugin password
crudini --set /etc/neutron/metadata_agent.ini DEFAULT project_domain_id default
crudini --set /etc/neutron/metadata_agent.ini DEFAULT user_domain_id default
crudini --set /etc/neutron/metadata_agent.ini DEFAULT project_name service
crudini --set /etc/neutron/metadata_agent.ini DEFAULT username neutron
crudini --set /etc/neutron/metadata_agent.ini DEFAULT password neutron
crudini --set /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_ip controller01
crudini --set /etc/neutron/metadata_agent.ini DEFAULT metadata_proxy_shared_secret $METADATA_SECRET

service nova-api restart
service neutron-metadata-agent restart

echo;
echo "##############################################################################################################

Neutron installation is complete.

###############################################################################################################"
echo;

# End
exit
