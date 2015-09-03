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

This script will install and configure MariaDB (MySQL) and should only be executed on the controller node

###############################################################################################################"
echo;

if [ $1 != "auto" ]; then
   read -n1 -rsp "Press any key to continue or control-c to cancel..." key
fi

# Install MySQL
sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password password openstack'
sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password openstack'
apt -y remove --purge mariadb-server python-mysqldb
apt-get clean
apt-get -y autoremove
updatedb
apt -y install mariadb-server python-mysqldb

# Configure MySQL
cat > /etc/mysql/conf.d/mysqld_openstack.cnf <<EOF
[mysqld]
bind-address = 10.254.254.100
default-storage-engine = innodb
innodb_file_per_table
collation-server = utf8_general_ci
init-connect = "SET NAMES utf8"
character-set-server = utf8
EOF

service mysql restart

# MySQL Install script
echo -e "openstack\nn\n\n\nn\n\n " | mysql_secure_installation 2>/dev/null

echo;
echo "##############################################################################################################

Database server installation is complete. You are free to run the installer and proceed with the Keystone installation.

###############################################################################################################"
echo;

# End
exit
