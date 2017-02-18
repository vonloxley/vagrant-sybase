# Sybase ASE in vagrant virtual machine

Installs and configures ready to use developer version of Sybase ASE.

## Settings

  * Port: 5001
  * System administrator (SA) user - username: sa, password: Sybase123
  * Test database: test
  * Test user - username: test, password: Test123
  * Collation/sorting: nocase
  * Charset: utf8
  * Initial database size: 500Mb

## Usage

  * Copy ASE_Suite.linuxamd64.tgz into folder (you can obtain it from http://www.sap.com/community/topic/ase.html)
  * ```git clone https://github.com/huksley/vagrant-sybase```
  * ```cd vagrant-sybase```
  * ```vagrant up```

## Customization and running

On _every_ vagrant provisioning database will be recreated!
Don`t keep important data and/or dml in database.

If you need additional customization check common.sh for settings.
