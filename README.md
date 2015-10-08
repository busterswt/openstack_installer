# openstack_installer

This is an bash-based installer for the Learning OpenStack Networking (Neutron) Second Edition book.

Certain pre-work must be done to the hosts to ensure a smooth installation.

Set the hostname of each machine (must reboot to take effect):

```
sudo hostnamectl set-hostname controller01.learningneutron.com
sudo hostnamectl set-hostname compute01.learningneutron.com
sudo hostnamectl set-hostname compute02.learningneutron.com
```

You must logout and log back in for changes to take effect.

---

Install the latest kernel and other packages with the following commands:

```
# May need to add key with the following command:
# sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 16126D3A3E5C1192

sudo apt-get -y update
sudo apt-get -u upgrade
sudo reboot
```

---


To use, execute the following on each host:

```
sudo apt -y install software-properties-common git
cd ~
git clone https://github.com/busterswt/openstack_installer.git --branch test --single-branch
cd ~/openstack_installer
sudo ./openstack_install.sh
```
