class { 'k3s':
  mode                  => 'server',
  cluster_init          => true,
  write_kubeconfig_mode => '0640',
  token                 => Sensitive(lookup('profile::k3s::token')),
  disable               => ['traefik'],
  node_labels           => ['role=control-plane', 'site=lab'],
}
