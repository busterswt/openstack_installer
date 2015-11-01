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

This script will update the system and install packages that are prerequisites for the installation of OpenStack.

After the script is finished you will be required to reboot the system.

###############################################################################################################"
echo;
read -n1 -rsp "Press any key to continue or control-c to cancel..." key

# Apt update
apt update

# Install cloud keyring
apt -y install ubuntu-cloud-keyring software-properties-common

# Configure repo
add-apt-repository cloud-archive:liberty

# Install Crudini
apt -y install crudini

# Install curl
apt -y install curl

# install time server
apt install ntp -y
service ntp restart

# Upgrade the system
apt update
apt -y dist-upgrade

# Install OpenStack client
apt-get -y install python-openstackclient

# Update /etc/hosts
cat > /etc/hosts <<EOF
127.0.0.1	localhost

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters

# OpenStack Hosts
$(echo ${controller01[mgmt_addr]}) controller01.learningneutron.com controller01
$(echo ${compute01[mgmt_addr]}) compute01.learningneutron.com compute01
$(echo ${compute02[mgmt_addr]}) compute02.learningneutron.com compute02
EOF

echo;
echo "##############################################################################################################

Please set the hostname of this machine and 'reboot' the system:

# For Controller01:
hostnamectl set-hostname controller01.learningneutron.com
reboot

# For Compute01:
hostnamectl set-hostname compute01.learningneutron.com
reboot

# For Compute02:
hostnamectl set-hostname compute02.learningneutron.com
reboot

###############################################################################################################"

exit
