#
# @summary Manage the k3s configuration files.
# @param mode
#   Desired node role, used to derive the matching environment file name.
# @param config_dir
#   Directory that contains the managed k3s configuration.
# @param config_file
#   Full path to the managed `config.yaml`.
# @param token
#   Optional cluster token as `Sensitive[String]`.
# @param server
#   Optional existing control-plane API endpoint for joining a cluster.
# @param cluster_init
#   Enables `cluster-init` for the initial server node.
# @param write_kubeconfig_mode
#   File mode used by k3s when writing the kubeconfig file on server nodes.
# @param node_name
#   Optional Kubernetes node name override.
# @param node_labels
#   Kubernetes node labels passed into the k3s configuration.
# @param node_taints
#   Kubernetes node taints passed into the k3s configuration.
# @param disable
#   Array of bundled server components to disable.
# @param flannel_backend
#   Optional flannel backend selection for server nodes.
# @param selinux
#   Whether the rendered `config.yaml` should set `selinux: true`.
class k3s::config (
  Enum['server', 'agent']         $mode,
  Stdlib::Absolutepath            $config_dir,
  Stdlib::Absolutepath            $config_file,
  Optional[Sensitive[String[1]]]  $token,
  Optional[String[1]]             $server,
  Boolean                         $cluster_init,
  Optional[String[1]]             $write_kubeconfig_mode,
  Optional[String[1]]             $node_name,
  Array[String[1]]                $node_labels,
  Array[String[1]]                $node_taints,
  Array[String[1]]                $disable,
  Optional[String[1]]             $flannel_backend,
  Boolean                         $selinux,
) {
  $service_name = $mode ? {
    'agent'  => 'k3s-agent',
    default  => 'k3s',
  }
  $service_env_file = "/etc/systemd/system/${service_name}.service.env"

  file { $config_dir:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0750',
  }

  file { $config_file:
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    content => epp('k3s/config.yaml.epp', {
        mode                  => $mode,
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
    }),
    require => File[$config_dir],
  }

  file { $service_env_file:
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    content => epp('k3s/service.env.epp', {
        mode => $mode,
    }),
    require => Exec['k3s_install_binary'],
  }
}
