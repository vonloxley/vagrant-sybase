#!/bin/bash

cd /vagrant
if [ ! -d ASE_Suite ]; then
	mkdir ASE_Suite
	cd ASE_Suite
	tar -xzvf ../ASE_Suite.linuxamd64.tgz
	cd ..
fi


echo "kernel.shmmax = 300000000" >> /etc/sysctl.conf
sysctl -p

groupadd sybase
useradd -g sybase -d /opt/sybase sybase
echo "sybase:Sybase123" | sudo chpasswd

mkdir -p /opt/sybase
chown sybase.sybase /opt/sybase

yum -y install unzip at
/etc/init.d/atd start

if [ ! -d /opt/sybase/ASE-16_0 ]; then
	echo "Installing Sybase ASE"
	cd /vagrant/ASE_Suite
	su -c "./setup.bin -f ../response.txt -i silent -DAGREE_TO_SAP_LICENSE=true" sybase
fi

cp /opt/sybase/jConnect-16_0/classes/jconn4.jar /vagrant
cp /vagrant/sqlsrv.res /opt/sybase/ASE-16_0/

# Sybase ASE must listen on real IP address
MYIP=`ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'`
echo $MYIP sybtest >> /etc/hosts

echo source /opt/sybase/SYBASE.sh >>/opt/sybase/.bashrc
source /opt/sybase/SYBASE.sh

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
echo "echo su -l -c /opt/sybase/ASE-16_0/install/RUN_SYBTEST sybase | at now" >> /etc/rc.d/rc.local

bash /etc/rc.d/rc.local
