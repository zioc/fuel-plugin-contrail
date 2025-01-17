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

class contrail::config ( $node_role ) {
  case $node_role {
    'controller','primary-controller': {
      nova_config {
        'DEFAULT/network_api_class': value=> 'nova.network.neutronv2.api.API';
        'DEFAULT/neutron_url': value => "http://${contrail::contrail_mgmt_vip}:9696";
        'DEFAULT/neutron_admin_tenant_name': value=> 'services';
        'DEFAULT/neutron_admin_username': value=> 'neutron';
        'DEFAULT/neutron_admin_password': value=> $contrail::service_token;
        'DEFAULT/neutron_url_timeout': value=> '300';
        'DEFAULT/neutron_admin_auth_url': value=> "http://${contrail::mos_mgmt_vip}:35357/v2.0/";
        'DEFAULT/firewall_driver': value=> 'nova.virt.firewall.NoopFirewallDriver';
        'DEFAULT/enabled_apis': value=> 'ec2,osapi_compute,metadata';
        'DEFAULT/security_group_api': value=> 'neutron';
        'DEFAULT/service_neutron_metadata_proxy': value=> 'True';
      } ->
      keystone_endpoint {'RegionOne/neutron':
        ensure => absent,
      }
      file {'/etc/haproxy/conf.d/094-web_for_contrail.cfg':
        ensure  => present,
        content => template('contrail/094-web_for_contrail.cfg.erb'),
        notify  => Service['haproxy'],
      } ->
      file {'/etc/haproxy/conf.d/095-rabbit_for_contrail.cfg':
        ensure  => present,
        content => template('contrail/095-rabbit_for_contrail.cfg.erb'),
        notify  => Service['haproxy'],
      } ~>
      service {'haproxy':
        ensure     => running,
        hasrestart => true,
        restart    => '/sbin/ip netns exec haproxy service haproxy reload',
      }
    }
    'compute': {
      nova_config {
        'DEFAULT/neutron_url': value => "http://${contrail::contrail_mgmt_vip}:9696";
        'DEFAULT/neutron_admin_auth_url': value=> "http://${contrail::mos_mgmt_vip}:35357/v2.0/";
        'DEFAULT/network_api_class': value=> 'nova_contrail_vif.contrailvif.ContrailNetworkAPI';
        'DEFAULT/neutron_admin_tenant_name': value=> 'services';
        'DEFAULT/neutron_admin_username': value=> 'neutron';
        'DEFAULT/neutron_admin_password': value=> $contrail::service_token;
        'DEFAULT/neutron_url_timeout': value=> '300';
        'DEFAULT/firewall_driver': value=> 'nova.virt.firewall.NoopFirewallDriver';
        'DEFAULT/security_group_api': value=> 'neutron';
      }

      $ipv4_file = $operatingsystem ? {
          'Ubuntu' => '/etc/iptables/rules.v4',
          'CentOS' => '/etc/sysconfig/iptables',
      }

      exec {'flush_nat':
        command => '/sbin/iptables -t nat -F'
      } ->

      firewall {'0000 metadata service':
        source  => '169.254.0.0/16',
        iniface => 'vhost0',
        action  => 'accept'
      } ->

      firewall {'0001 juniper contrail rules':
        proto  => 'tcp',
        dport  => ['2049','8085','9090','8102','33617','39704','44177','55970','60663'],
        action => 'accept'
      } ->

      exec { 'persist-firewall':
        command     => "/sbin/iptables-save > ${ipv4_file}",
        user        => 'root',
      }

      file {'/etc/contrail/agent_param':
        ensure  => present,
        content => template('contrail/agent_param.erb'),
      }
      file {'/etc/contrail/contrail-vrouter-agent.conf':
        ensure  => present,
        content => template('contrail/contrail-vrouter-agent.conf.erb'),
      }

    }

    'base-os': {

      # Switch neutron and contrail-api to MOS controller's RabbitMQ

      # Contrail-api
      ini_setting { 'contrail_rabbit_server':
          ensure  => present,
          path    => '/etc/contrail/contrail-api.conf',
          section => 'DEFAULTS',
          setting => 'rabbit_server',
          value   => $contrail::mos_mgmt_vip
      } ->
      ini_setting { 'contrail_rabbit_port':
          ensure  => present,
          path    => '/etc/contrail/contrail-api.conf',
          section => 'DEFAULTS',
          setting => 'rabbit_port',
          value   => '5673'
      } ->
      ini_setting { 'contrail_rabbit_user':
          ensure  => present,
          path    => '/etc/contrail/contrail-api.conf',
          section => 'DEFAULTS',
          setting => 'rabbit_user',
          value   => 'nova'
      } ->
      ini_setting { 'contrail_rabbit_password':
          ensure  => present,
          path    => '/etc/contrail/contrail-api.conf',
          section => 'DEFAULTS',
          setting => 'rabbit_password',
          value   => $contrail::rabbit_password
      } ->

      # Neutron
      ini_setting { 'neutron_admin_password':
          ensure  => present,
          path    => '/etc/neutron/neutron.conf',
          section => 'keystone_authtoken',
          setting => 'admin_password',
          value   => $contrail::service_token
      } ->
      ini_setting { 'neutron_rabbit_hosts':
          ensure  => present,
          path    => '/etc/neutron/neutron.conf',
          section => 'DEFAULT',
          setting => 'rabbit_hosts',
          value   => $contrail::rabbit_hosts_ports
      } ->
      ini_setting { 'neutron_rabbit_host': # Set empty
          ensure  => present,
          path    => '/etc/neutron/neutron.conf',
          section => 'DEFAULT',
          setting => 'rabbit_host',
          value   => ''
      } ->
      ini_setting { 'neutron_rabbit_port':
          ensure  => present,
          path    => '/etc/neutron/neutron.conf',
          section => 'DEFAULT',
          setting => 'rabbit_port',
          value   => '5673'
      } ->
      ini_setting { 'neutron_rabbit_userid':
          ensure  => present,
          path    => '/etc/neutron/neutron.conf',
          section => 'DEFAULT',
          setting => 'rabbit_userid',
          value   => 'nova'
      } ->
      ini_setting { 'neutron_rabbit_password':
          ensure  => present,
          path    => '/etc/neutron/neutron.conf',
          section => 'DEFAULT',
          setting => 'rabbit_password',
          value   => $contrail::rabbit_password
      }
    }
  }
}
