#!/bin/bash
#
# Author :  Sonal Arora
#
#
# Licenced under GPLv3, check LICENSE.txt
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

error=0;

red=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`
function pass {
	echo "${green} $1 ...........[OK]  ${reset}"
}
function fail {
        echo "${red} $1 ..........[FAIL] ${reset}"
}

function check {
# usage :
#   check <exit code> <What are we checking>
if [ "$1" == "0" ]; then
	pass "$2";
else
	fail "$2";
	error=1;
fi
}

function subscription {
echo "Checking if the system is subscribed"
val=$(subscription-manager status|grep -i status:|awk '{print $NF}');
if [ "$val" == "Current" ];then
	check 0 'Checking if system is subscribed'
else
	check 2 'Checking if system is subscribed'
fi
}

function repos {
echo
echo "Checking for required repositories"
TEMP=`mktemp /tmp/temporary-file.XXXXXXXX`

yum repolist  > $TEMP
cat $TEMP|grep -i 'rhel-7-server-rpms' > /dev/null
check $? 'Checking for rhel-7-server-rpms' 
cat $TEMP|grep -i 'rhel-7-server-ose-3.10-rpms' > /dev/null
check $? 'Checking for rhel-7-server-ose-3.10-rpms'
cat $TEMP|grep -i 'rhel-7-server-ansible-2.4-rpms' > /dev/null
check $? 'Checking for rhel-7-server-ose-3.10-rpms'
cat $TEMP|grep -i 'rhel-7-server-extras-rpms' > /dev/null
check $? 'Checking for rhel-7-server-extras-rpms'



}
 
function package_check {
	rpm -q $1 > /dev/null 2> /dev/null
	check $? "Checking if package $1 is installed"
}

function package_list {
echo
echo "Checking if required packages are installed"
pkg='wget git net-tools bind-utils iptables-services bridge-utils bash-completion kexec-tools sos psacct openshift-ansible docker' 
for i in $pkg; do
package_check $i
done
}

function exit {
	echo 
	echo   "  Summary :"
	echo .............
	if [ "$error" == "1" ];then
		fail "Please fix the above issue and run again"
	else
		pass "All prequisites have been completed successfully"
	fi
	echo .............
}
function passwordless_ssh {
echo "Checking for password less ssh to hosts"

cat /root/hostname
check $? 'Checking for /root/hostname which contains list of all other nodes'

 for host in $(cat /root/hostname); do ssh $host hostname > /dev/null;check $? "checking for passwordless ssh to $host"; done

}
function docker_setup {
echo
echo "Checking for docker setup"
systemctl is-enabled docker
check $? 'Checking if docker is enabled'
systemctl is-active docker
check $? 'Checking if docker is running'
vg=$(cat /etc/sysconfig/docker-storage-setup|grep -iv "#"|grep  VG|cut -f2 -d "="|head -1)
if [ -z "$vg" ]; then 
	check 2 'Checking VG config in /etc/sysconfig/docker-storage-setup'
else
	check 0 'Checking VG config in /etc/sysconfig/docker-storage-setup'
fi

vgs|grep -i $vg
check $? 'Checking if the VG has been created'
lvs |grep -i docker-pool
check $? 'Checking if docker-pool lvm exits'
#grep -i docker-vg /etc/sysconfig/docker-storage-setup
}
function dns {
echo
echo Checking for DNS config
dns=$(grep -i peerdns /etc/sysconfig/network-scripts/ifcfg-eth0|cut -f2 -d "="|grep -i no)
check $? 'Checking if peerdns=no in /etc/sysconfig/network-scripts/ifcfg-eth0'
ip_eth0=$(ip addr show dev eth0|grep -i inet|head -1|awk '{print $2}'|cut -f1 -d "/")
resolved_ip_from_dns=$(dig `hostname` @10.75.5.25 +short)
if [ "$ip_eth0" == "$resolved_ip_from_dns" ]; then
	check 0 'Checking if hostname is resolable by DNS'
else
	check 1 'Checking if hostname is resolable by DNS'
fi
}
subscription
repos
package_list
dns
passwordless_ssh
#docker_setup
exit

