include contrail


case $operatingsystem {
  Ubuntu: {

    class { 'contrail::package':
      install => ['contrail-openstack-vrouter','contrail-vrouter-dkms','iproute2','haproxy','libatm1'],
      remove  => ['openvswitch-common','openvswitch-datapath-lts-saucy-dkms','openvswitch-switch','nova-network','nova-api'],
      }

  }
  CentOS: {

    class { 'contrail::package':
      install => ['contrail-openstack-vrouter','iproute','haproxy'],
      }
  }
}

class { 'contrail::network':
  node_role => 'compute',
  address   => $contrail::address,
  ifname    => $contrail::ifname,
  netmask   => $contrail::netmask_short,
  require   => Class['contrail::package']
} ->

class { 'contrail::config':
  node_role => $contrail::node_role,
} ->

class { 'contrail::provision':
  node_role => $contrail::node_role,
}