#
# @summary Install and manage k3s on Linux hosts.
# @param mode
#   Controls whether the node is configured as a `server` or an `agent`.
# @param ensure
#   Whether k3s should be installed (`present`) or uninstalled (`absent`).
# @param channel
#   Upstream k3s release channel, for example `stable`, `latest`, or `testing`.
# @param version
#   Optional pinned k3s version such as `v1.30.4+k3s1`.
# @param manage_prerequisites
#   When true, install the prerequisite operating system packages before
#   downloading k3s.
# @param packages
#   Either a flat array of package names or an OS-family keyed hash of package
#   lists.
# @param config_dir
#   Directory that contains the managed k3s configuration.
# @param config_file
#   Full path to the managed `config.yaml` file.
# @param token
#   Optional cluster token as `Sensitive[String]`. Store this in encrypted Hiera
#   or another secret backend.
# @param server
#   API endpoint of an existing k3s server. Required for agents and for
#   additional server nodes that join an existing cluster.
# @param cluster_init
#   Enables `cluster-init` for the first control-plane node in an embedded etcd
#   topology.
# @param write_kubeconfig_mode
#   File mode used by k3s when writing the kubeconfig file on server nodes.
# @param node_name
#   Optional Kubernetes node name override.
# @param node_labels
#   Array of Kubernetes node labels to pass into the k3s configuration.
# @param node_taints
#   Array of Kubernetes node taints to pass into the k3s configuration.
# @param disable
#   Array of bundled server components to disable, for example `['traefik']`.
# @param flannel_backend
#   Optional flannel backend selection for server nodes.
# @param selinux
#   Enables `selinux: true` in the k3s config for SELinux-capable platforms.
# @param service_enable
#   Whether the resulting systemd service should be enabled at boot.
# @param service_ensure
#   Desired service state for the node.
class k3s (
  Enum['server', 'agent']         $mode = 'server',
  Enum['present', 'absent']       $ensure = 'present',
  String[1]                       $channel = 'stable',
  Optional[String[1]]             $version = undef,
  Boolean                         $manage_prerequisites = true,
  Variant[Array[String[1]], Hash[String[1], Array[String[1]]]] $packages = {
    'Debian' => ['curl', 'ca-certificates'],
    'RedHat' => ['curl', 'ca-certificates'],
  },
  Stdlib::Absolutepath            $config_dir = '/etc/rancher/k3s',
  Stdlib::Absolutepath            $config_file = '/etc/rancher/k3s/config.yaml',
  Optional[Sensitive[String[1]]]  $token = undef,
  Optional[String[1]]             $server = undef,
  Boolean                         $cluster_init = false,
  String[1]                       $write_kubeconfig_mode = '0640',
  Optional[String[1]]             $node_name = undef,
  Array[String[1]]                $node_labels = [],
  Array[String[1]]                $node_taints = [],
  Array[String[1]]                $disable = [],
  Optional[String[1]]             $flannel_backend = undef,
  Boolean                         $selinux = $facts['os']['family'] == 'RedHat',
  Boolean                         $service_enable = true,
  Enum['running', 'stopped']      $service_ensure = 'running',
) {
  $resolved_packages = $packages ? {
    Hash    => pick($packages[$facts['os']['family']], []),
    default => $packages,
  }

  if $ensure == 'present' and $mode == 'agent' and $server == undef {
    fail('k3s: parameter server is required when mode => agent')
  }

  if $ensure == 'present' and $cluster_init and $server != undef {
    fail('k3s: cluster_init and server are mutually exclusive')
  }

  if $ensure == 'present' {
    class { 'k3s::install':
      mode                 => $mode,
      channel              => $channel,
      version              => $version,
      manage_prerequisites => $manage_prerequisites,
      packages             => $resolved_packages,
      selinux              => $selinux,
    }

    class { 'k3s::config':
      mode                  => $mode,
      config_dir            => $config_dir,
      config_file           => $config_file,
      token                 => $token,
      server                => $server,
      cluster_init          => $cluster_init,
      write_kubeconfig_mode => $write_kubeconfig_mode,
      node_name             => $node_name,
      node_labels           => $node_labels,
      node_taints           => $node_taints,
      disable               => $disable,
      flannel_backend       => $flannel_backend,
      selinux               => $selinux,
    }

    class { 'k3s::service':
      mode           => $mode,
      config_file    => $config_file,
      service_enable => $service_enable,
      service_ensure => $service_ensure,
    }

    Class['k3s::install']
    -> Class['k3s::config']
    ~> Class['k3s::service']
  } else {
    class { 'k3s::uninstall':
      mode        => $mode,
      config_dir  => $config_dir,
      config_file => $config_file,
    }
  }
}
