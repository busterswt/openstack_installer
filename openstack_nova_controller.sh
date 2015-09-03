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

This script will install and configure Nova (Compute Service) and should only be executed on the controller node.

WARNING: Any existing Nova configuration will be lost!

###############################################################################################################"
echo;

if [ $1 != "auto" ]; then
  read -n1 -rsp "Press any key to continue or control-c to cancel..." key
fi

# Install Nova (Controller Only)
apt-get -y install nova-api nova-cert nova-conductor nova-consoleauth nova-novncproxy nova-scheduler python-novaclient

# Remove temp DB
rm -f /var/lib/nova/nova.sqlite

# Configure DB
mysql -u root -popenstack -e "DROP DATABASE nova;"
mysql -u root -popenstack -e "CREATE DATABASE nova;"
mysql -u root -popenstack -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY 'nova';"
mysql -u root -popenstack -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY 'nova';"

# Configure Nova
crudini --set /etc/nova/nova.conf DEFAULT rpc_backend rabbit
crudini --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_host controller01
crudini --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_userid openstack
crudini --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_password rabbit

crudini --set /etc/nova/nova.conf DEFAULT my_ip 10.254.254.100
crudini --set /etc/nova/nova.conf DEFAULT vncserver_listen 10.254.254.100
crudini --set /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address 10.254.254.100

source ~/adminrc
openstack user create --password nova nova
openstack role add --project service --user nova admin

crudini --set /etc/nova/nova.conf DEFAULT auth_strategy keystone
crudini --set /etc/nova/nova.conf keystone_authtoken auth_uri http://controller01:5000
crudini --set /etc/nova/nova.conf keystone_authtoken auth_url http://controller01:35357
crudini --set /etc/nova/nova.conf keystone_authtoken auth_plugin password
crudini --set /etc/nova/nova.conf keystone_authtoken project_domain_id default
crudini --set /etc/nova/nova.conf keystone_authtoken user_domain_id default
crudini --set /etc/nova/nova.conf keystone_authtoken project_name service
crudini --set /etc/nova/nova.conf keystone_authtoken username nova
crudini --set /etc/nova/nova.conf keystone_authtoken password nova

# Create endpoints
openstack service create --name nova --description "OpenStack Compute" compute

openstack endpoint create \
--publicurl http://controller01:8774/v2/%\(tenant_id\)s \
--internalurl http://controller01:8774/v2/%\(tenant_id\)s \
--adminurl http://controller01:8774/v2/%\(tenant_id\)s \
--region RegionOne \
compute

crudini --set /etc/nova/nova.conf glance host controller01
crudini --set /etc/nova/nova.conf oslo_concurrency lock_path /var/lib/nova/tmp

# Sync DB
su -s /bin/sh -c "nova-manage db sync" nova

# Restart services
service nova-api restart
service nova-cert restart
service nova-consoleauth restart
service nova-scheduler restart
service nova-conductor restart
service nova-novncproxy restart

echo;
echo "##############################################################################################################

Nova installation is complete.

###############################################################################################################"
echo;

# End
exit
