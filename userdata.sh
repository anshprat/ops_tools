#!/bin/bash
# USerdata.sh. 
# This script can be used as userdata script with cloudinit.
# It installs and configures puppet master and puppet agent with provided
# configuration
#
# == Variables
# proxy: Proxy server url. e.g. proxy="http://10.1.1.1:3128". leave it blank if
# there is no proxy server
#
# puppetmaster_name: FQDN of puppetmaster. e.g puppetmaster_name=puppetmaster.example.com
#
# puppetmaster_ip: IP address of puppet master.

release="$(lsb_release -cs)"
proxy=''
puppetmaster_name=''
puppetmaster_ip=''

if [ `echo $proxy | grep -c "[a-z0-9][a-z0-9]*"` -ne 0 ]; then
  export http_proxy=$proxy
  export https_proxy=$proxy
  cat <<EOF > /etc/apt/apt.conf.d/03proxy 
Acquire::http { Proxy "$proxy" }
EOF
fi

wget -O puppet.deb http://apt.puppetlabs.com/puppetlabs-release-${release}.deb
dpkg -i puppet.deb
apt-get update
if [ `echo $puppetmaster_name | grep -c "[a-z0-9][a-z0-9]*"` -eq 0 ]; then
  apt-get install -y puppetmaster
   puppet module install fsalum-puppetmaster
  cat <<EOF > /etc/puppet/manifests/puppetmaster.pp
#package { 'puppetmaster-passenger': 
#  ensure => installed, 
#}

class { puppetmaster:
  puppetmaster_service_ensure       => 'running',
  puppetmaster_service_enable       => 'true',
  puppetmaster_report               => 'true',
  puppetmaster_autosign             => 'true',
  puppetmaster_modulepath           => '$confdir/modules:$confdir/modules-0',
}
EOF
  puppet apply --modulepath /etc/puppet/modules /etc/puppet/manifests/puppetmaster.pp
else
  if [ `echo $puppetmaster_ip | grep -Pc "\d+\.\d+\.\d+\.\d+"` -eq 0 ]; then
    echo "Puppet master IP must be provided for non-puppetmaster nodes"
    exit 1
  fi
  apt-get install -y puppet
   puppet module install puppetlabs-stdlib
   puppet module install puppetlabs-inifile
  cat <<EOF > /etc/puppet/manifests/puppetagent.pp
host {'$puppetmaster_name':
  ip => '$puppetmaster_ip'
}

ini_setting {'puppet-server':
  path     => '/etc/puppet/puppet.conf',
  section  => 'main',
  setting  => 'server',
  value    => '$puppetmaster_name'
}

file_line {'enable_puppetagent':
  path  => '/etc/default/puppet',
  line  => 'START=yes',
  match => '^START=.*',
}

service {'puppet':
  ensure => running,
  enable => true,
}
EOF
  puppet apply --modulepath /etc/puppet/modules /etc/puppet/manifests/puppetagent.pp
fi
