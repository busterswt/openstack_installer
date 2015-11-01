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

This script will install and configure Keystone (Identity Service) and should only be executed on the controller node

###############################################################################################################"
echo;

if [ $1 != "auto" ]; then
   read -n1 -rsp "Press any key to continue or control-c to cancel..." key
fi

# Configure DB
mysql -u root -popenstack -e "DROP DATABASE keystone;"
mysql -u root -popenstack -e "CREATE DATABASE keystone;"
mysql -u root -popenstack -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY 'keystone';"
mysql -u root -popenstack -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY 'keystone';"

# Configure override to avoid service start
echo "manual" > /etc/init/keystone.override

# Install Keystone
apt-get -y install keystone python-openstackclient apache2 libapache2-mod-wsgi memcached python-memcache

# Remove lite db
rm -f /var/lib/keystone/keystone.db

# Configure Keystone
ADMIN_TOKEN="insecuretoken123"
crudini --set /etc/keystone/keystone.conf database connection mysql+pymysql://keystone:keystone@controller01/keystone
crudini --set /etc/keystone/keystone.conf memcache servers localhost:11211
crudini --set /etc/keystone/keystone.conf DEFAULT admin_token insecuretoken123
crudini --set /etc/keystone/keystone.conf token provider uuid
crudini --set /etc/keystone/keystone.conf token driver memcache
crudini --set /etc/keystone/keystone.conf revoke driver sql

# Populate Keystone DB
su -s /bin/sh -c "keystone-manage db_sync" keystone

# Configure Apache
cat > /etc/apache2/sites-available/wsgi-keystone.conf <<EOF
Listen 5000
Listen 35357

<VirtualHost *:5000>
    WSGIDaemonProcess keystone-public processes=5 threads=1 user=keystone group=keystone display-name=%{GROUP}
    WSGIProcessGroup keystone-public
    WSGIScriptAlias / /usr/bin/keystone-wsgi-public
    WSGIApplicationGroup %{GLOBAL}
    WSGIPassAuthorization On
    <IfVersion >= 2.4>
      ErrorLogFormat "%{cu}t %M"
    </IfVersion>
    ErrorLog /var/log/apache2/keystone.log
    CustomLog /var/log/apache2/keystone_access.log combined

    <Directory /usr/bin>
        <IfVersion >= 2.4>
            Require all granted
        </IfVersion>
        <IfVersion < 2.4>
            Order allow,deny
            Allow from all
        </IfVersion>
    </Directory>
</VirtualHost>

<VirtualHost *:35357>
    WSGIDaemonProcess keystone-admin processes=5 threads=1 user=keystone group=keystone display-name=%{GROUP}
    WSGIProcessGroup keystone-admin
    WSGIScriptAlias / /usr/bin/keystone-wsgi-admin
    WSGIApplicationGroup %{GLOBAL}
    WSGIPassAuthorization On
    <IfVersion >= 2.4>
      ErrorLogFormat "%{cu}t %M"
    </IfVersion>
    ErrorLog /var/log/apache2/keystone.log
    CustomLog /var/log/apache2/keystone_access.log combined

    <Directory /usr/bin>
        <IfVersion >= 2.4>
            Require all granted
        </IfVersion>
        <IfVersion < 2.4>
            Order allow,deny
            Allow from all
        </IfVersion>
    </Directory>
</VirtualHost>
EOF

ln -s /etc/apache2/sites-available/wsgi-keystone.conf /etc/apache2/sites-enabled
#mkdir -p /var/www/cgi-bin/keystone
#curl http://git.openstack.org/cgit/openstack/keystone/plain/httpd/keystone.py?h=stable/kilo | tee /var/www/cgi-bin/keystone/main /var/www/cgi-bin/keystone/admin
#chown -R keystone:keystone /var/www/cgi-bin/keystone 
#chmod 755 /var/www/cgi-bin/keystone/*

# Restart Apache
service apache2 restart

# Configure Endpoints
export OS_TOKEN=$ADMIN_TOKEN
export OS_URL=http://controller01:35357/v3
export OS_IDENTITY_API_VERSION=3

openstack service create --name keystone --description "OpenStack Identity" identity

openstack endpoint create --region RegionOne identity public http://controller01:5000/v2.0
openstack endpoint create --region RegionOne identity internal http://controller01:5000/v2.0
openstack endpoint create --region RegionOne identity admin http://controller01:35357/v2.0

# Configure projects and users
openstack project create --domain default --description "Admin Project" admin
openstack project create --domain default --description "Service Project" service
openstack project create --domain default --description "Demo Project" demo

openstack user create --domain default --password secrete admin
openstack role create admin
openstack role add --project admin --user admin admin

openstack user create --domain default --password demo demo
openstack role create user
openstack role add --project demo --user demo user

# Test
unset OS_TOKEN OS_URL
openstack --os-auth-url http://controller01:35357 --os-project-name admin --os-username admin --os-password secrete token issue

openstack --os-auth-url http://controller01:35357 \
--os-project-name admin --os-username admin \
--os-password secrete project list

# Create rc files
cat > ~/adminrc <<EOF
export OS_PROJECT_DOMAIN_ID=default
export OS_USER_DOMAIN_ID=default
export OS_PROJECT_NAME=admin
export OS_TENANT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=secrete
export OS_AUTH_URL=http://controller01:35357/v3
export OS_IDENTITY_API_VERSION=3
EOF

cat > ~/demorc <<EOF
export OS_PROJECT_DOMAIN_ID=default
export OS_USER_DOMAIN_ID=default
export OS_PROJECT_NAME=demo
export OS_TENANT_NAME=demo
export OS_USERNAME=demo
export OS_PASSWORD=demo
export OS_AUTH_URL=http://controller01:5000/v3
export OS_IDENTITY_API_VERSION=3
EOF

echo;
echo "##############################################################################################################

Keystone installation is complete!

The following rc files have been created to assist with using the OpenStack CLI:

~/adminrc
~/demorc

You may now proceed with the installation of Glance.

###############################################################################################################"
echo;

# End
exit
