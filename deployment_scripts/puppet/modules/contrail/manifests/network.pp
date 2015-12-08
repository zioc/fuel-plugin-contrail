#    Copyright 2015 Mirantis, Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

class contrail::network {
  $br_file = $::operatingsystem ? {
      'Ubuntu' => "/etc/network/interfaces.d/ifcfg-${contrail::data_interface}",
      'CentOS' => "/etc/sysconfig/network-scripts/ifcfg-${contrail::data_interface}",
  }

  Exec {
    provider => 'shell',
    path => '/usr/bin:/bin:/sbin',
  }

  file { $br_file: ensure => absent } ->
  # Remove interface from the bridge
  exec {"remove_${contrail::data_phys_dev}_mesh":
    command => "brctl delif ${contrail::data_interface} ${contrail::data_phys_dev}",
    returns => [0,1] # Idempotent
  } ->
  exec {'flush_addr_br_mesh':
    command => "ip addr flush dev ${contrail::data_interface}",
    returns => [0,1] # Idempotent
  }
  case $::operatingsystem {
    'Ubuntu': {
      file {'/etc/network/interfaces.d/ifcfg-vhost0':
        ensure  => present,
        content => template('contrail/ubuntu-ifcfg-vhost0.erb'),
      }
    }
    'CentOS': {
      exec {"remove_bridge_from_${contrail::data_phys_dev}_config":
        command => "sed -i '/BRIDGE/d' /etc/sysconfig/network-scripts/ifcfg-${contrail::data_phys_dev}",
      }
      file {'/etc/sysconfig/network-scripts/ifcfg-vhost0':
        ensure  => present,
        content => template('contrail/centos-ifcfg-vhost0.erb'),
      }
    }
    default: {}
  }
}

