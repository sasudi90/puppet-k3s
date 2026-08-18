class { 'k3s':
  ensure => 'absent',
  mode   => 'server',
}
