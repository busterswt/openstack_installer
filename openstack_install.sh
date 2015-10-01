#!/bin/bash
echo;
echo "Welcome to the OpenStack Networking Essentials OpenStack Installer!"
echo;

echo "Importing config.ini..."
eval "$(cat config.ini  | ./scripts/ini2arr.py)"

function cleanup {
   break
   exit
}
trap cleanup SIGHUP SIGINT SIGTERM

PS3='Please enter your choice: '
options=("Install Prerequisites" "Automated Controller Node Installation" "Automated Compute Node Installation (LinuxBridge)" "Automated Compute Node Installation (Open vSwitch)" "Install Database Server (Warning: Destroys Existing Cloud)" "Install Keystone (Warning: Destroys existing Keystone DB)" "Install Glance" "Install Nova Components (Controller Only)" "Install Neutron Components (Controller Only)" "Quit")
select opt in "${options[@]}"
do
    case $opt in
        "Install Prerequisites")
           sudo /bin/bash ~/openstack_installer/openstack_pre.sh
	   break
	   ;;
        "Automated Controller Node Installation")
	   read -n1 -resp $'\nThis will kickoff an unattended installation on the controller node.\n\n Press any key to continue or control-c to cancel...\n' key
           sudo /bin/bash ~/openstack_installer/openstack_amqp.sh auto
	   sudo /bin/bash ~/openstack_installer/openstack_mysql.sh auto
           sudo /bin/bash ~/openstack_installer/openstack_keystone.sh auto
           sudo /bin/bash ~/openstack_installer/openstack_glance.sh auto
           sudo /bin/bash ~/openstack_installer/openstack_nova_controller.sh auto
	   sudo /bin/bash ~/openstack_installer/openstack_dashboard.sh auto
           sudo /bin/bash ~/openstack_installer/openstack_neutron_controller.sh auto
           if  [ $(echo ${network[vswitch]}) == "linuxbridge" ]; then
             sudo /bin/bash ~/openstack_installer/openstack_neutron_controller_lb.sh auto
           elif [ $(echo ${network[vswitch]}) == "ovs" ]; then
             sudo /bin/bash ~/openstack_installer/openstack_neutron_l3_controller_lb.sh auto
           else
             echo "vswitch not configured. Please set config.ini and run again"
             break
           fi
           break
           ;;
        "Automated Compute Node Installation (LinuxBridge)")
           read -n1 -resp $'\nThis will kickoff an unattended installation on a compute node.\n\n Press any key to continue or control-c to cancel...\n' key
           sudo /bin/bash ~/openstack_installer/openstack_nova_compute.sh auto
           sudo /bin/bash ~/openstack_installer/openstack_neutron_compute.sh auto
           sudo /bin/bash ~/openstack_installer/openstack_neutron_compute_lb.sh auto
           break
           ;;
        "Automated Compute Node Installation (Open vSwitch)")
           read -n1 -resp $'\nThis will kickoff an unattended installation on a compute node.\n\n Press any key to continue or control-c to cancel...\n' key
           sudo /bin/bash ~/openstack_installer/openstack_nova_compute.sh auto
           sudo /bin/bash ~/openstack_installer/openstack_neutron_compute.sh auto
           sudo /bin/bash ~/openstack_installer/openstack_neutron_compute_ovs.sh auto
           break
           ;;
        "Install Database Server (Warning: Destroys Existing Cloud)")
	   sudo /bin/bash ~/openstack_installer/openstack_mysql.sh
	   break
            ;;
        "Install Keystone (Warning: Destroys existing Keystone DB)")
	   sudo /bin/bash ~/openstack_installer/openstack_keystone.sh
           break
            ;;
	"Install Glance")
           sudo /bin/bash ~/openstack_installer/openstack_glance.sh
           break
	   ;;
	"Install Nova Components (Controller Only)")
	   sudo /bin/bash ~/openstack_installer/openstack_nova_controller.sh
           break
	   ;;
	"Install Neutron Components (Controller Only)")
	   sudo /bin/bash ~/openstack_installer/openstack_neutron_controller.sh
	   break
	   ;;
        "Quit")
           echo "Bye!" 
	   break
            ;;
        *) echo invalid option;;
    esac
done
