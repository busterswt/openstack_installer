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

This script will install and configure Horizon (OpenStack Dashboard) and should only be executed on the controller node

###############################################################################################################"
echo;

if [ $1 != "auto" ]; then
   read -n1 -rsp "Press any key to continue or control-c to cancel..." key
fi

# Install Horizon
apt-get -y install openstack-dashboard

# Setup Horizon
sed -i '/OPENSTACK_HOST \=/c\OPENSTACK_HOST = \"controller01\"' /etc/openstack-dashboard/local_settings.py
sed -i '/OPENSTACK_KEYSTONE_DEFAULT_ROLE \=/c\OPENSTACK_KEYSTONE_DEFAULT_ROLE = \"user\"' /etc/openstack-dashboard/local_settings.py

# Restart Apache
service apache2 reload

# Remove Ubuntu Theme
apt-get -y remove openstack-dashboard-ubuntu-theme

echo;
echo "##############################################################################################################

Horizon installation is complete.

###############################################################################################################"
echo;

# End
exit
