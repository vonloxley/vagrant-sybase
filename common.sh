#!/bin/bash

cd /vagrant
if [ ! -d ASE_Suite ]; then
	tar -xzvf ASE_Suite.linuxamd64.tgz
fi

if [ -d /vagrant/deb ]; then
	# Install from cache
	dpkg -i /vagrant/deb/*.deb
else 
	dpkg --add-architecture i386	
	apt-get update
	apt-get upgrade -y
	apt-get install -y libaio1 libc6:i386 libncurses5:i386 libstdc++6:i386
	mkdir -p /vagrant/deb
	rm -Rf /vagrant/deb/*.deb
	cp /var/cache/apt/archives/*.deb /vagrant/deb/
fi

cd ASE_Suite

echo "kernel.shmmax = 300000000" >> /etc/sysctl.conf
sysctl -p

groupadd -g 500 sybase
useradd -g sybase -G admin -d /opt/sybase -u 500 sybase
echo "sybase:Sybase123" | sudo chpasswd

mkdir -p /opt/sybase
chown sybase.sybase /opt/sybase

if [ ! -d /opt/sybase/ASE-16_0 ]; then
	echo "Installing Sybase ASE"
	su -c "./setup.bin -f ../response.txt -i silent -DAGREE_TO_SAP_LICENSE=true" sybase
fi


cp /opt/sybase/jConnect-16_0/classes/jconn4.jar /vagrant
cp /vagrant/sqlsrv.res /opt/sybase/ASE-16_0/

# Sybase ASE must listen on real IP address
MYIP=`ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'`
echo $MYIP sybtest >> /etc/hosts

echo source ./SYBASE.sh >>/opt/sybase/.profile
su - sybase

cat <<EOF >/tmp/asestop
shutdown
go
EOF

isql -S SYBTEST -U sa -P Sybase123 -i /tmp/asestop

rm -Rf /opt/sybase/data/*.dat
rm -Rf /opt/sybase/interfaces
rm -Rf /opt/sybase/ASE-16_0/TEST.*
rm -Rf /opt/sybase/ASE-16_0/SYBTEST.*
rm -Rf /opt/sybase/ASE-16_0/sysam/*.properties
rm -Rf /opt/sybase/ASE-16_0/install/RUN_*
rm -Rf /opt/sybase/ASE-16_0/install/*.log

echo Building Sybase ASE server
srvbuildres -r /opt/sybase/ASE-16_0/sqlsrv.res

