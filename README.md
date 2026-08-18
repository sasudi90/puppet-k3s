# k3s

Puppet module to install and manage `k3s` on Debian, Ubuntu, Red Hat Enterprise
Linux, CentOS, Rocky, AlmaLinux, Oracle Linux, and Fedora.

The intended platform design is:

1. Terraform provisions the VM.
2. Terraform bootstraps the Puppet agent.
3. Puppet owns the host configuration and installs/configures `k3s`.

This keeps infrastructure provisioning separate from host lifecycle management,
which is the right split if you want repeatability, cleaner drift control, and a
clear operational ownership model.

## Design

The module is split into three internal classes:

- `k3s::install` installs prerequisites, downloads the upstream `k3s` installer,
  and installs the binary and systemd units.
- `k3s::config` manages `/etc/rancher/k3s/config.yaml` and the matching systemd
  environment file.
- `k3s::service` reloads systemd and manages the `k3s` or `k3s-agent` service.
- `k3s::uninstall` stops the service, runs the upstream uninstall helper when
  available, and removes managed files.

The module intentionally uses the upstream installer at `https://get.k3s.io`.
For `k3s`, this is the standard and supported installation path across Debian-
and RedHat-family systems. It also avoids maintaining separate repository logic
per platform.

## What This Module Manages

- prerequisite packages such as `curl` and `ca-certificates`
- `/usr/local/sbin/k3s-install.sh`
- `/etc/rancher/k3s/config.yaml`
- `/etc/systemd/system/k3s.service.env` or
  `/etc/systemd/system/k3s-agent.service.env`
- the `k3s` or `k3s-agent` systemd service

## Requirements

- Puppet `>= 7.24 < 9.0.0`
- `puppetlabs/stdlib`
- systemd-based Linux hosts
- outbound access to `https://get.k3s.io` during installation

## Usage

### Single-node server

```puppet
class { 'k3s':
  mode                  => 'server',
  cluster_init          => true,
  write_kubeconfig_mode => '0640',
  token                 => Sensitive(lookup('profile::k3s::token')),
  disable               => ['traefik'],
  node_labels           => ['role=control-plane', 'site=lab'],
}
```

### Additional server node

```puppet
class { 'k3s':
  mode        => 'server',
  server      => 'https://10.42.0.10:6443',
  token       => Sensitive(lookup('profile::k3s::token')),
  node_labels => ['role=control-plane'],
  node_taints => ['node-role.kubernetes.io/control-plane=true:NoSchedule'],
}
```

### Agent node

```puppet
class { 'k3s':
  mode        => 'agent',
  server      => 'https://10.42.0.10:6443',
  token       => Sensitive(lookup('profile::k3s::token')),
  node_labels => ['role=worker', 'site=pmx-lab'],
}
```

### Pin a specific version

```puppet
class { 'k3s':
  mode    => 'server',
  version => 'v1.30.4+k3s1',
  token   => Sensitive(lookup('profile::k3s::token')),
}
```

### Uninstall k3s

```puppet
class { 'k3s':
  ensure => 'absent',
  mode   => 'server',
}
```

## Hiera Example

```yaml
profile::k3s::token: ENC[PKCS7,...]

k3s::mode: server
k3s::cluster_init: true
k3s::disable:
  - traefik
k3s::node_labels:
  - role=control-plane
  - env=lab
```

Do not hardcode cluster tokens in manifests. Store them in Hiera EYAML, Vault, or
another encrypted backend.

## Parameters

The most relevant class parameters are:

- `mode`: `server` or `agent`
- `ensure`: `present` or `absent`
- `channel`: upstream release channel, defaults to `stable`
- `version`: optional pinned `k3s` version
- `token`: optional cluster token as `Sensitive[String]`
- `server`: required for `agent` mode, optional for joining an existing server
- `cluster_init`: enables `cluster-init` for the first server
- `node_labels`: list of Kubernetes node labels
- `node_taints`: list of Kubernetes taints
- `disable`: list of server components to disable, for example `['traefik']`
- `service_enable` / `service_ensure`: systemd service state control

## Operational Notes

- This module is designed for installation and steady-state configuration.
- `ensure => absent` uses the upstream uninstall script when available and then
  removes the remaining managed files.
- It does **not** currently orchestrate safe in-place `k3s` upgrades.
- It assumes Terraform or another provisioning workflow already handled base VM
  creation, networking, DNS, storage layout, and Puppet bootstrap.
- If you run on SELinux-enabled Red Hat systems, validate your site policy and
  test networking and storage paths as part of acceptance.

## Limitations

- systemd-only
- no bundled firewall management
- no HA etcd lifecycle orchestration beyond passing `k3s` configuration

Those are deliberate scope boundaries. In production, firewall policy, load
balancing, storage classes, backup, and cluster lifecycle should normally be
handled in higher-level profiles or roles rather than hidden inside a base
installation module.

## Development

Useful commands:

```bash
bundle install
bundle exec rake spec_prep
bundle exec rake validate
bundle exec rake spec
bundle exec rake metadata_lint
```
