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

This script will remove your OpenStack installation.

# Will want to check for file on install. If it exists, for user to delete install and delete file in this script.

###############################################################################################################"
echo;

if [ $1 != "auto" ]; then
   read -n1 -rsp "Press any key to continue or control-c to cancel..." key
fi

# Delete everything!

echo "Removing instances if they exist..."
for x in $(virsh list --all | grep instance- | awk '{print $2}') ; do
    virsh destroy $x ;
    virsh undefine $x ;
done ;

# Warning! Dangerous step! Removes lots of packages
echo "Removing packages..."
apt-get -y remove --purge 'ntp.*' 'openstack.*' \
'nova.*' 'keystone.*' 'glance.*' 'rabbit.*' \
'neutron.*' 'mysql.*' 'maria.*' 'mysql-server.*' 'apache2.*' 'memcache.*' 'openvswitch.*' ;
apt-get clean
apt-get -y autoremove

# Warning! Dangerous step! Deletes local application data
echo "Deleting files..."
rm -rf /root/.my.cnf /var/lib/mysql/ /var/lib/glance /var/lib/nova /var/lib/neutron /var/lib/openstack-dashboard \
/var/log/keystone /var/log/neutron/ /var/log/apache2 /var/log/glance/ /var/log/neutron/ /usr/share/openstack-dashboard/ \
/etc/neutron /etc/nova /etc/keystone /etc/glance /etc/openstack-dashboard/ /etc/mysql/ /etc/rabbitmq/ /etc/apache2/ \
/var/lib/openvswitch/ ;

# Remove install file
rm /var/lib/openstack_installer/installed
rm -rf /var/lib/openstack_installer/

# End
exit
