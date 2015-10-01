# openstack_installer

This is an bash-based installer for the Learning OpenStack Networking (Neutron) Second Edition book.

Certain pre-work must be done to the hosts to ensure a smooth installation.

Set the hostname of each machine (must reboot to take effect):

```
hostnamectl set-hostname controller01.learningneutron.com
hostnamectl set-hostname compute01.learningneutron.com
hostnamectl set-hostname compute02.learningneutron.com
```
---
To use, execute the following on each host:

```
sudo apt-get -y update
sudo apt -y install software-properties-common git
cd ~
git clone https://github.com/busterswt/openstack_installer.git
cd ~/openstack_installer
```
