#!/bin/bash

cd /vagrant
if [ ! -d ASE_Suite ]; then
	tar -xzvf ASE_Suite.linuxamd64.tgz
fi


if [ ! -f /vagrant/.installed ]; then
	touch /vagrant/.installed

	if [ -d /vagrant/deb ]; then
		# Install from cache
		dpkg -i /vagrant/deb/*.deb
	fi

	if [ ! -d /vagrant/deb ]; then
		dpkg --add-architecture i386	
		apt-get update
		apt-get upgrade -y
		apt-get install -y libaio1 libc6:i386 libncurses5:i386 libstdc++6:i386
		mkdir -p /vagrant/deb
		rm -Rf /vagrant/deb/*.deb
		cp /var/cache/apt/archives/*.deb /vagrant/deb/
	fi
fi

echo "kernel.shmmax = 300000000" >> /etc/sysctl.conf
sysctl -p

groupadd -g 500 sybase
useradd -g sybase -G admin -d /opt/sybase -u 500 sybase
echo "sybase:Sybase123" | sudo chpasswd

mkdir -p /opt/sybase
chown sybase.sybase /opt/sybase

if [ ! -d /opt/sybase/ASE-16_0 ]; then
	echo "Installing Sybase ASE"
	cd ASE_Suite
	su -c "./setup.bin -f ../response.txt -i silent -DAGREE_TO_SAP_LICENSE=true" sybase
fi

cp /opt/sybase/jConnect-16_0/classes/jconn4.jar /vagrant
cp /vagrant/sqlsrv.res /opt/sybase/ASE-16_0/

# Sybase ASE must listen on real IP address
MYIP=`ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'`
echo $MYIP sybtest >> /etc/hosts

echo source ./SYBASE.sh >>/opt/sybase/.profile

cat <<EOF >/tmp/asestop
shutdown
go
EOF

su -l -c "isql -S SYBTEST -U sa -P Sybase123 -i /tmp/asestop" sybase

rm -Rf /opt/sybase/data/*.dat
rm -Rf /opt/sybase/interfaces
rm -Rf /opt/sybase/ASE-16_0/TEST.*
rm -Rf /opt/sybase/ASE-16_0/SYBTEST.*
rm -Rf /opt/sybase/ASE-16_0/sysam/*.properties
rm -Rf /opt/sybase/ASE-16_0/install/RUN_*
rm -Rf /opt/sybase/ASE-16_0/install/*.log

echo Building Sybase ASE server
su -l -c "srvbuildres -r /opt/sybase/ASE-16_0/sqlsrv.res" sybase

# Load charset
su -l -c "export DSQUERY=SYBTEST; charset -Usa -PSybase123 binary.srt utf8" sybase


# Init nocase sorting + utf8 charset, test DB and user
cat <<EOF >/tmp/aseconf
exec sp_configure 'default sortorder id', 52, 'utf8'
go
disk init name = 'user_file_test1', physname = '/opt/sybase/data/test1.dat', size = '500M'
go
create database test on user_file_test1
go
exec master..sp_dboption test, 'allow nulls by default', true
exec master..sp_dboption test, 'trunc log on chkpt', true
exec master..sp_dboption test, 'abort tran on log full', true
exec master..sp_dboption test, 'ddl in tran', true
exec master..sp_dboption test, 'select into/bulkcopy','true'

go
use test
exec sp_addlogin 'test', 'Test123', 'test'
exec sp_addalias 'test', 'dbo'
go
shutdown
go
EOF

# Feed config
su -l -c "isql -S SYBTEST -U sa -P Sybase123 -i /tmp/aseconf" sybase

# Run once (will quit)
su -l -c "/opt/sybase/ASE-16_0/install/RUN_SYBTEST" sybase

# Run again
su -l -c "nohup /opt/sybase/ASE-16_0/install/RUN_SYBTEST &" sybase

# Add to start automatically
chmod a+x /etc/rc.local
echo "nohup /opt/sybase/ASE-16_0/install/RUN_SYBTEST &" >> /etc/rc.local

