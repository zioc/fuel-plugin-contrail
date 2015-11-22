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

class opencontrail::database {

  Package {
    ensure => installed,
  }
  File {
    ensure  => present,
    mode    => '0644',
    owner   => root,
    group   => root,
  }
  Exec { path => '/usr/bin:/usr/sbin:/bin:/sbin' }

  define exec_cmd {
    exec { "executing $name":
      command => "$name"
    }
  }

  file {'/etc/apt/sources.list.d/cassandra.list':
    ensure => file,
    source => 'puppet:///modules/opencontrail/cassandra.list',
  } ->
  exec_cmd {
    [ "gpg --keyserver pgp.mit.edu --recv-keys 2B5C1B00",
      "gpg --export --armor 2B5C1B00 | sudo apt-key add -",
      "gpg --keyserver pgp.mit.edu --recv-keys F758CE318D77295D",
      "gpg --export --armor F758CE318D77295D | sudo apt-key add -",
      "gpg --keyserver pgp.mit.edu --recv-keys 0353B12C",
      "gpg --export --armor 0353B12C | sudo apt-key add -",
      "apt-get update"
    ]:
  } ->

# Packages
  package { 'openjdk-7-jre-headless': } ->
  package { 'zookeeperd': } ->
  package { 'cassandra': } ->
  package { 'kafka': } ->
  package { 'supervisor': } ->
  package { 'contrail-utils': } ->
  package { 'contrail-nodemgr': }

# Zookeeper
  file { '/etc/zookeeper/conf/myid':
    content => $contrail::uid,
    require => Package['zookeeperd'],
  }

  file { '/etc/zookeeper/conf/zoo.cfg':
    content => template('contrail/zoo.cfg.erb');
  }

  service { 'zookeeper':
    ensure    => running,
    enable    => true,
    require   => [Package['zookeeperd']],
    subscribe => [File['/etc/zookeeper/conf/zoo.cfg'],
                  File['/etc/zookeeper/conf/myid'],
                  ],
  }

# Cassandra
  file { '/var/lib/cassandra':
    ensure  => directory,
    mode    => '0755',
    owner   => 'cassandra',
    group   => 'cassandra',
    require => Package['cassandra'],
  } ->
  file { '/var/crashes':
    ensure => directory,
    mode   => '0777',
  } ->
  file { '/etc/cassandra/cassandra.yaml':
    content => template('contrail/cassandra.yaml.erb'),
  }
  ->
  file { '/etc/cassandra/cassandra-env.sh':
    source  => 'puppet:///modules/contrail/cassandra-env.sh',
  }

# Services

  service { 'cassandra':
    ensure    => running,
    enable    => true,
    require   => [File['/var/lib/cassandra'],Package['cassandra']],
    subscribe => [
      File['/etc/cassandra/cassandra.yaml'],
      File['/etc/cassandra/cassandra-env.sh'],
    ],
  }

  notify{ 'Waiting for cassandra seed node': } ->
  exec { 'wait_for_cassandra_seed':
    provider  => 'shell',
    command   => "nodetool status|grep ^UN|grep ${contrail::primary_contrail_db_ip}",
    tries     => 10, # wait for whole cluster is up: 10 tries every 30 seconds = 5 min
    try_sleep => 30,
    require   => Service['cassandra'],
  }

  notify{ 'Waiting for cassandra': } ->
  exec { 'wait_for_cassandra':
    provider  => 'shell',
    command   => "nodetool status|grep ^UN|grep ${contrail::address}",
    tries     => 10, # wait for whole cluster is up: 10 tries every 30 seconds = 5 min
    try_sleep => 30,
    require   => Service['cassandra'],
  }
}
