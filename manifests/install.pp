#
# @summary Install the k3s binaries and bootstrap systemd units.
# @param mode
#   Desired node role, used to derive the target systemd service.
# @param channel
#   Upstream k3s release channel.
# @param version
#   Optional pinned k3s version.
# @param manage_prerequisites
#   Whether prerequisite packages should be installed.
# @param packages
#   Package list to install before downloading and running the upstream
#   installer.
# @param selinux
#   When true, include SELinux-aware installer behaviour on RedHat-family
#   systems.
class k3s::install (
  Enum['server', 'agent'] $mode,
  String[1]               $channel,
  Optional[String[1]]     $version,
  Boolean                 $manage_prerequisites,
  Array[String[1]]        $packages,
  Boolean                 $selinux,
) {
  $install_script_path = '/usr/local/sbin/k3s-install.sh'
  $install_binary_path = '/usr/local/bin/k3s'

  $service_name = $mode ? {
    'agent'  => 'k3s-agent',
    default  => 'k3s',
  }
  $service_env_file = "/etc/systemd/system/${service_name}.service.env"

  if $manage_prerequisites and !empty($packages) {
    package { $packages:
      ensure => installed,
    }
  }

  file { '/usr/local/sbin':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  exec { 'k3s_download_installer':
    command => "/usr/bin/curl -fsSL https://get.k3s.io -o ${install_script_path} && /usr/bin/chmod 0750 ${install_script_path}",
    creates => $install_script_path,
    path    => ['/usr/bin', '/usr/sbin', '/bin', '/sbin'],
    require => File['/usr/local/sbin'],
  }

  $base_environment = [
    "INSTALL_K3S_EXEC=${mode}",
    'INSTALL_K3S_SKIP_START=true',
    "INSTALL_K3S_CHANNEL=${channel}",
  ]
  $version_environment = if $version {
    ["INSTALL_K3S_VERSION=${version}"]
  } else {
    []
  }
  $selinux_environment = if $selinux {
    ['INSTALL_K3S_SELINUX_WARN=true']
  } else {
    []
  }
  $install_environment = $base_environment + $version_environment + $selinux_environment

  exec { 'k3s_install_binary':
    command     => $install_script_path,
    creates     => $install_binary_path,
    environment => $install_environment,
    path        => ['/usr/bin', '/usr/sbin', '/bin', '/sbin'],
    require     => Exec['k3s_download_installer'],
    before      => File[$service_env_file],
  }
}
