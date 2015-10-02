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

This script will install and configure Nova (Compute Service) and should only be executed on the compute node

###############################################################################################################"
echo;
if [ $1 != "auto" ]; then
   read -n1 -rsp "Press any key to continue or control-c to cancel..." key
fi
# Install Nova (Compute Only)
apt-get -y install nova-compute sysfsutils qemu-kvm

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

#Grab my IP
MY_NAME=$(hostname -s)
MY_MGMT_IP=$MY_NAME[mgmt_addr]

crudini --set /etc/nova/nova.conf DEFAULT my_ip $(echo "${!MY_MGMT_IP}")
crudini --set /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address $(echo "${!MY_MGMT_IP}")
crudini --set /etc/nova/nova.conf DEFAULT vnc_enabled True
crudini --set /etc/nova/nova.conf DEFAULT vncserver_listen 0.0.0.0
crudini --set /etc/nova/nova.conf DEFAULT novncproxy_base_url http://controller01:6080/vnc_auto.html

crudini --set /etc/nova/nova.conf glance host controller01
crudini --set /etc/nova/nova.conf oslo_concurrency lock_path /var/lib/nova/tmp

# Configure Nova for QEMU (emulation)
crudini --set /etc/nova/nova-compute.conf libvirt virt_type $(echo ${virt[virt_type]})

# Restart Nova
service nova-compute restart

echo;
echo "##############################################################################################################

Nova installation is complete.

###############################################################################################################"
echo;

# End
exit
