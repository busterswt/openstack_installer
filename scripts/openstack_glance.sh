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

This script will install and configure Glance (Image Service) and should only be executed on the controller node

###############################################################################################################"
echo;

if [ $1 != "auto" ]; then
   read -n1 -rsp "Press any key to continue or control-c to cancel..." key
fi

# Install Glance
apt-get -y install glance python-glanceclient

# Remove temp DB
rm -f /var/lib/glance/glance.sqlite

# Configure DB
mysql -u root -popenstack -e "DROP database glance;"
mysql -u root -popenstack -e "CREATE DATABASE glance;"
mysql -u root -popenstack -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY 'glance';"
mysql -u root -popenstack -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY 'glance';"

# Configure Glance
crudini --set /etc/glance/glance-api.conf database connection mysql+pymysql://glance:glance@controller01/glance
crudini --set /etc/glance/glance-registry.conf database connection mysql+pymysql://glance:glance@controller01/glance

source ~/adminrc
openstack user create --domain default --password glance glance
openstack role add --project service --user glance admin

crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_uri http://controller01:5000/v2.0
crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_url http://controller01:35357
crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_plugin password
crudini --set /etc/glance/glance-api.conf keystone_authtoken user_domain_id default
crudini --set /etc/glance/glance-api.conf keystone_authtoken project_domain_id default
crudini --set /etc/glance/glance-api.conf keystone_authtoken project_name service
crudini --set /etc/glance/glance-api.conf keystone_authtoken username glance
crudini --set /etc/glance/glance-api.conf keystone_authtoken password glance

crudini --set /etc/glance/glance-registry.conf keystone_authtoken auth_uri http://controller01:5000/v2.0
crudini --set /etc/glance/glance-registry.conf keystone_authtoken auth_url http://controller01:35357
crudini --set /etc/glance/glance-registry.conf keystone_authtoken auth_plugin password
crudini --set /etc/glance/glance-registry.conf keystone_authtoken user_domain_id default
crudini --set /etc/glance/glance-registry.conf keystone_authtoken project_domain_id default
crudini --set /etc/glance/glance-registry.conf keystone_authtoken project_name service
crudini --set /etc/glance/glance-registry.conf keystone_authtoken username glance
crudini --set /etc/glance/glance-registry.conf keystone_authtoken password glance

crudini --set /etc/glance/glance-api.conf paste_deploy flavor keystone
crudini --set /etc/glance/glance-api.conf glance_store default_store file
crudini --set /etc/glance/glance-api.conf glance_store filesystem_store_datadir /var/lib/glance/images
crudini --set /etc/glance/glance-api.conf DEFAULT notification_driver noop

crudini --set /etc/glance/glance-registry.conf paste_deploy flavor keystone
crudini --set /etc/glance/glance-registry.conf DEFAULT notification_driver noop

# Sync DB
su -s /bin/sh -c "glance-manage db_sync" glance

# Restart Glance
service glance-registry restart
service glance-api restart

# Configure Endpoints
openstack service create --name glance --description "OpenStack Image service" image
openstack endpoint create --region RegionOne image public http://controller01:9292
openstack endpoint create --region RegionOne image internal http://controller01:9292
openstack endpoint create --region RegionOne image admin http://controller01:9292

# Update rc
echo "export OS_IMAGE_API_VERSION=2" | tee -a ~/adminrc ~/demorc

# Upload CirrOS Image
source ~/adminrc

mkdir /tmp/images

if [ ! -f "/tmp/images/cirros-0.3.4-x86_64-disk.img" ]; then
    wget -P /tmp/images http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img
fi

glance image-create --name "cirros-0.3.4-x86_64" \
  --file /tmp/images/cirros-0.3.4-x86_64-disk.img \
  --disk-format qcow2 --container-format bare \
  --visibility public --progress

# Upload Ubuntu Image
#if [ ! -f "/tmp/images/trusty-server-cloudimg-amd64-disk1.img" ]; then
#   wget -P /tmp/images https://cloud-images.ubuntu.com/trusty/current/trusty-server-cloudimg-amd64-disk1.img
#fi

#glance image-create --name="Ubuntu 14.04 LTS Cloud Image" --file=/tmp/images/trusty-server-cloudimg-amd64-disk1.img --disk-format qcow2 --container-format bare --visibility public --progress

echo;
echo "##############################################################################################################

Glance installation is complete. The following images have been created:

cirros-0.3.4-x86_64 (Testing)
Ubuntu 14.04 LTS Cloud Image

###############################################################################################################"
echo;

# End
exit
