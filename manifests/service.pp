#
# @summary Manage the k3s systemd service lifecycle.
# @param mode
#   Desired node role, used to derive the target service name.
# @param config_file
#   Full path to the managed k3s configuration file.
# @param service_enable
#   Whether the resulting systemd service should be enabled at boot.
# @param service_ensure
#   Desired systemd service state.
class k3s::service (
  Enum['server', 'agent']    $mode,
  Boolean                    $service_enable,
  Enum['running', 'stopped'] $service_ensure,
  Stdlib::Absolutepath       $config_file = '/etc/rancher/k3s/config.yaml',
) {
  $service_name = $mode ? {
    'agent'  => 'k3s-agent',
    default  => 'k3s',
  }
  $service_env_file = "/etc/systemd/system/${service_name}.service.env"

  exec { "systemd_daemon_reload_${service_name}":
    command     => '/usr/bin/systemctl daemon-reload',
    refreshonly => true,
    path        => ['/usr/bin', '/usr/sbin', '/bin', '/sbin'],
  }

  File[$service_env_file]
  ~> Exec["systemd_daemon_reload_${service_name}"]

  service { $service_name:
    ensure    => $service_ensure,
    enable    => $service_enable,
    provider  => 'systemd',
    subscribe => [
      File[$config_file],
      File[$service_env_file],
    ],
    require   => [
      Exec['k3s_install_binary'],
      File[$config_file],
      File[$service_env_file],
    ],
  }
}
