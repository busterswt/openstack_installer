#!/bin/bash
echo;
echo "Welcome to the OpenStack Networking Essentials OpenStack Installer!"
echo;
echo "This installer is meant for the controller node only."
echo "Please exit the installer if this has been executed in error."
echo;

function cleanup {
   break
   exit
}
trap cleanup SIGHUP SIGINT SIGTERM

PS3='Please enter your choice: '
options=("Install Prerequisites" "Automated Controller Installation" "Install Database Server (Warning: Destroys Existing Cloud)" "Install Keystone (Warning: Destroys existing Keystone DB)" "Install Glance" "Install Nova Components (Controller Only)" "Install Neutron Components (Controller Only)" "Quit")
select opt in "${options[@]}"
do
    case $opt in
        "Install Prerequisites")
           sudo /bin/bash ~/openstack_pre.sh
	   break
	   ;;
        "Automated Controller Installation")
	   read -n1 -resp $'\nThis will kickoff an unattended installation on the controller node.\n\n Press any key to continue or control-c to cancel...\n' key
           sudo /bin/bash ~/openstack_mysql.sh auto
           sudo /bin/bash ~/openstack_keystone.sh auto
           sudo /bin/bash ~/openstack_glance.sh auto
           sudo /bin/bash ~/openstack_nova_controller.sh auto
           sudo /bin/bash ~/openstack_neutron_controller.sh auto
           break
           ;;
        "Install Database Server (Warning: Destroys Existing Cloud)")
	   sudo /bin/bash ~/openstack_mysql.sh
	   break
            ;;
        "Install Keystone (Warning: Destroys existing Keystone DB)")
	   sudo /bin/bash ~/openstack_keystone.sh
           break
            ;;
	"Install Glance")
           sudo /bin/bash ~/openstack_glance.sh
           break
	   ;;
	"Install Nova Components (Controller Only)")
	   sudo /bin/bash ~/openstack_nova_controller.sh
           break
	   ;;
	"Install Neutron Components (Controller Only)")
	   sudo /bin/bash ~/openstack_neutron_controller.sh
	   break
	   ;;
        "Quit")
            break
            ;;
        *) echo invalid option;;
    esac
done
