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
options=("Install Prerequisites" "Automated Controller Node Installation" "Automated Compute Node Installation" "Destroy everything!" "Quit")
select opt in "${options[@]}"
do
    case $opt in
        "Install Prerequisites")
           sudo /bin/bash ./scripts/openstack_pre.sh
	   break
	   ;;
        "Automated Controller Node Installation")
	   read -n1 -resp $'\nThis will kickoff a (mostly) unattended installation on the controller node.\n\n Press any key to continue or control-c to cancel...\n' key

           # Check for install file
           if [ -f /var/lib/openstack_installer/installed ]; then
             echo "Existing installation found! Please run the uninstaller and try again."
             break
           else
             # Create a file so we know some components are installed
             mkdir /var/lib/openstack_installer/
             touch /var/lib/openstack_installer/installed

             # Begin executing scripts to install various components
             sudo /bin/bash ./scripts/openstack_amqp.sh auto
             sudo /bin/bash ./scripts/openstack_mysql.sh auto
             sudo /bin/bash ./scripts/openstack_keystone.sh auto
             sudo /bin/bash ./scripts/openstack_glance.sh auto
             sudo /bin/bash ./scripts/openstack_nova_controller.sh auto
	     sudo /bin/bash ./scripts/openstack_dashboard.sh auto
             sudo /bin/bash ./scripts/openstack_neutron_controller.sh auto
           
             if  [ $(echo ${network[vswitch]}) = "linuxbridge" ]; then
               sudo /bin/bash ./scripts/openstack_neutron_controller_lb.sh auto
             elif [ $(echo ${network[vswitch]}) = "ovs" ]; then
               sudo /bin/bash ./scripts/openstack_neutron_controller_ovs.sh auto
             else
               echo "vswitch not configured. Please set config.ini and run again"
               break
             fi
             sudo /bin/bash ./scripts/openstack_neutron_l3_controller.sh auto
           fi
           break
           ;;
        "Automated Compute Node Installation")
           read -n1 -resp $'\nThis will kickoff a (mostly) unattended installation on a compute node.\n\n Press any key to continue or control-c to cancel...\n' key
           sudo /bin/bash ./scripts/openstack_nova_compute.sh auto
           sudo /bin/bash ./scripts/openstack_neutron_compute.sh auto
           if  [ $(echo ${network[vswitch]}) == "linuxbridge" ]; then
             sudo /bin/bash ./scripts/openstack_neutron_compute_lb.sh auto
           elif [ $(echo ${network[vswitch]}) == "ovs" ]; then
             sudo /bin/bash ./scripts/openstack_neutron_compute_ovs.sh auto
           else
             echo "vswitch not configured. Please set config.ini and run again"
             break
           fi
           break
           ;;
	"Destroy everything!")
	  read -n1 -resp $'\nThis will remove OpenStack packages and configuration.\n\n Press any key to continue or control-c to cancel...\n' key
	  sudo /bin/bash ./scripts/purge_everything.sh auto
	  break
	  ;;
        "Quit")
           echo "Bye!" 
	   break
            ;;
        *) echo invalid option;;
    esac
done
