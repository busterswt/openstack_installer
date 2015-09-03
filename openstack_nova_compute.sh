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

This script will install and configure Nova (Compute Service) and should only be executed on the compute node

###############################################################################################################"
echo;
if [ $1 != "auto" ]; then
   read -n1 -rsp "Press any key to continue or control-c to cancel..." key
fi
# Install Nova (Compute Only)
apt-get -y install nova-compute sysfsutils

# Configure Nova
crudini --set /etc/nova/nova.conf DEFAULT auth_strategy keystone
crudini --set /etc/nova/nova.conf keystone_authtoken auth_uri http://controller01:5000
crudini --set /etc/nova/nova.conf keystone_authtoken auth_url http://controller01:35357
crudini --set /etc/nova/nova.conf keystone_authtoken auth_plugin password
crudini --set /etc/nova/nova.conf keystone_authtoken project_domain_id default
crudini --set /etc/nova/nova.conf keystone_authtoken user_domain_id default
crudini --set /etc/nova/nova.conf keystone_authtoken project_name service
crudini --set /etc/nova/nova.conf keystone_authtoken username nova
crudini --set /etc/nova/nova.conf keystone_authtoken password nova

crudini --set /etc/nova/nova.conf DEFAULT rpc_backend rabbit
crudini --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_host controller01
crudini --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_userid openstack
crudini --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_password rabbit

crudini --set /etc/nova/nova.conf DEFAULT my_ip $(ip r | grep 10.254.254 | awk {'print $9'})
crudini --set /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address $(ip r | grep 10.254.254 | awk {'print $9'})
crudini --set /etc/nova/nova.conf DEFAULT vnc_enabled True
crudini --set /etc/nova/nova.conf DEFAULT vncserver_listen 0.0.0.0
crudini --set /etc/nova/nova.conf DEFAULT novncproxy_base_url http://controller01:6080/vnc_auto.html

crudini --set /etc/nova/nova.conf glance host controller01
crudini --set /etc/nova/nova.conf oslo_concurrency lock_path /var/lib/nova/tmp

# Configure Nova for QEMU (emulation)
crudini --set /etc/nova/nova.conf DEFAULT compute_driver libvirt.LibvirtDriver
crudini --set /etc/nova/nova.conf libvirt virt_type qemu

# Restart Nova
service nova-compute restart

echo;
echo "##############################################################################################################

Nova installation is complete.

###############################################################################################################"
echo;

# End
exit
