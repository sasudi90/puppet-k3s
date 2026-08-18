class { 'k3s':
  mode        => 'agent',
  server      => 'https://10.42.0.10:6443',
  token       => Sensitive(lookup('profile::k3s::token')),
  node_labels => ['role=worker', 'site=lab'],
}
