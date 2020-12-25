#!/bin/bash

########################################
# Install MySQL
########################################

export DEBIAN_FRONTEND=noninteractive
apt-get install -qqy percona-xtradb-cluster-server percona-xtradb-cluster-galera-2.x

service mysql stop

cp /etc/mysql/my.cnf{,.orig}
cp /vagrant/resources/my.cnf.$(uname -n) /etc/mysql/my.cnf

if [ "$(uname -n)" = "db01" ] 
then
  # Bootstrap the cluster - only on the master the first time.
  service mysql bootstrap-pxc
  mysql -e "CREATE USER 'sstuser'@'localhost' IDENTIFIED BY 'sstuser';"
  mysql -e "GRANT RELOAD, LOCK TABLES, REPLICATION CLIENT ON *.* TO 'sstuser'@'localhost';"

  mysql -e "GRANT PROCESS ON *.* TO 'clustercheckuser'@'localhost' IDENTIFIED BY 'clustercheckpassword!';"

  mysql -e 'CREATE DATABASE wordpress;'
  mysql -e 'CREATE USER wordpress IDENTIFIED BY "wordpress";'
  mysql -e 'GRANT ALL PRIVILEGES ON wordpress.* TO wordpress'
  mysql -e 'FLUSH PRIVILEGES;'

  # mysql -e "show status like 'wsrep%';"
else
  service mysql start
fi

# For the clustercheck script
cp /etc/services{,.orig}
echo 'mysqlchk 9200/tcp # mysqlchk' >> /etc/services
apt-get install -qqy xinetd

## You can disable apparmor for mysqld, just to be safe.
#cd /etc/apparmor.d/disable/
#ln -s /etc/apparmor.d/usr.sbin.mysqld
#service apparmor restart

# The world is all sunshine and rainbows.
exit 0 
