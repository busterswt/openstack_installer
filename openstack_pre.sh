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

This script will update the system and install packages that are prerequisites for the installation of OpenStack.

After the script is finished you will be required to reboot the system.

###############################################################################################################"
echo;
read -n1 -rsp "Press any key to continue or control-c to cancel..." key

# Apt update
apt update

# Install cloud keyring
apt -y install ubuntu-cloud-keyring

# Configure repo
echo "deb http://ubuntu-cloud.archive.canonical.com/ubuntu" "trusty-updates/kilo main" > /etc/apt/sources.list.d/cloudarchive-kilo.list

# Install Crudini
apt -y install crudini

# install time server
apt install ntp -y
service ntp restart

# Upgrade the system
apt update
apt -y dist-upgrade

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
