#!/bin/bash

########################################
# Install keepalived
########################################
apt-get install -qqy keepalived

cp /vagrant/resources/keepalived.conf.$(uname -n) /etc/keepalived/keepalived.conf

service keepalived start


########################################
# Install haproxy
########################################
apt-get install -qqy haproxy

# Enable haproxy
sed -i.orig 's/ENABLED=.*/ENABLED=1/' /etc/default/haproxy

cp /etc/haproxy/haproxy.cfg{,.orig}
cp /vagrant/resources/haproxy.cfg /etc/haproxy/


# Configure logging
cp /vagrant/resources/udp-localhost.conf /etc/rsyslog.d/
service rsyslog restart

service haproxy start


########################################
# Install Apache/PHP
########################################
apt-get install -qqy apache2 php5 php5-gd php5-curl php5-mysql
cp /etc/apache2/ports.conf{,.orig}
cp /vagrant/resources/ports.conf /etc/apache2/


########################################
# Install Gluster
########################################
# Let's use names instead of IPs.  Add that info to /etc/hosts
cp /etc/hosts{,.orig} 
cat /vagrant/resources/hosts >> /etc/hosts

apt-get install -qqy glusterfs-server

# Create a brick
apt-get install -qqy xfsprogs
[ "$(uname -n)" = "server01" ] && mkdir -p /data/glusterfs/var-www/brick01
[ "$(uname -n)" = "server02" ] && mkdir -p /data/glusterfs/var-www/brick02

cp /etc/fstab{,.orig}
echo "$(uname -n)-private:/var-www /var/www glusterfs defaults,_netdev,fetch-attempts=5 0 0" >> /etc/fstab

# Stop apache to ensure it's not using /var/www
service apache2 stop
mv /var/www{,.orig}
mkdir /var/www

# Only run on one node.
[ "$(uname -n)" = "server02" ] && {
  gluster peer probe server01-private
  gluster volume create var-www replica 2 transport tcp server01-private:/data/glusterfs/var-www/brick01/brick server02-private:/data/glusterfs/var-www/brick02/brick force
  gluster volume start var-www
  mount /var/www
  ssh -o StrictHostKeyChecking=no -i /vagrant/resources/insecure_private_key vagrant@server01 "sudo service apache2 stop ; sudo mount /var/www; sudo service apache2 start"
}

########################################
# Install Wordpress
########################################

cp /vagrant/resources/wordpress.conf /etc/apache2/sites-available/
a2ensite wordpress

a2enmod rewrite

a2dissite default
a2dissite 000-default

service apache2 restart

# Only run on one node.
[ "$(uname -n)" = "server02" ] && {
  cd /var/tmp
  wget -q https://wordpress.org/latest.tar.gz
  tar xf /var/tmp/latest.tar.gz -C /var/www
  chown -R www-data:www-data /var/www/wordpress

  cd /var/www/wordpress
  cp -p wp-config-sample.php wp-config.php
  sed -i "s/define('DB_NAME'.*/define('DB_NAME', 'wordpress');/" wp-config.php
  sed -i "s/define('DB_USER'.*/define('DB_USER', 'wordpress');/" wp-config.php
  sed -i "s/define('DB_PASSWORD'.*/define('DB_PASSWORD', 'wordpress');/" wp-config.php
  sed -i "s/define('DB_HOST'.*/define('DB_HOST', '127.0.0.1');/" wp-config.php

  cp /vagrant/resources/session.php /var/www/wordpress/
  cp /vagrant/resources/which-server.php /var/www/wordpress/
}


# The world is all sunshine and rainbows.
exit 0 
