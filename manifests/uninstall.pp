#
# @summary Uninstall k3s and remove managed configuration.
# @param mode
#   Desired node role, used to derive the correct uninstall script and service.
# @param config_dir
#   Directory that contains the managed k3s configuration.
# @param config_file
#   Full path to the managed `config.yaml`.
class k3s::uninstall (
  Enum['server', 'agent'] $mode,
  Stdlib::Absolutepath    $config_dir,
  Stdlib::Absolutepath    $config_file,
) {
  $service_name = $mode ? {
    'agent'  => 'k3s-agent',
    default  => 'k3s',
  }
  $service_env_file = "/etc/systemd/system/${service_name}.service.env"
  $uninstall_script = $mode ? {
    'agent'  => '/usr/local/bin/k3s-agent-uninstall.sh',
    default  => '/usr/local/bin/k3s-uninstall.sh',
  }

  exec { "k3s_stop_${service_name}":
    command => "/usr/bin/systemctl disable --now ${service_name}",
    onlyif  => "/usr/bin/test -f /etc/systemd/system/${service_name}.service -o -f /usr/lib/systemd/system/${service_name}.service",
    path    => ['/usr/bin', '/usr/sbin', '/bin', '/sbin'],
  }

  exec { "k3s_uninstall_${service_name}":
    command => $uninstall_script,
    onlyif  => "/usr/bin/test -x ${uninstall_script}",
    path    => ['/usr/bin', '/usr/sbin', '/bin', '/sbin'],
    require => Exec["k3s_stop_${service_name}"],
  }

  file { [
      $config_file,
      $service_env_file,
      '/usr/local/bin/k3s',
      '/usr/local/bin/k3s-killall.sh',
      '/usr/local/bin/k3s-uninstall.sh',
      '/usr/local/bin/k3s-agent-uninstall.sh',
      '/usr/local/sbin/k3s-install.sh',
    ]:
      ensure => absent,
  }

  file { $config_dir:
    ensure  => absent,
    force   => true,
    recurse => true,
    require => Exec["k3s_uninstall_${service_name}"],
  }
}
