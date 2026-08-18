# frozen_string_literal: true

require 'spec_helper'

describe 'k3s' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:expected_packages) { %w[curl ca-certificates] }

      it { is_expected.to compile.with_all_deps }

      it 'installs the expected prerequisite package set' do
        expected_packages.each do |package_name|
          is_expected.to contain_package(package_name).with_ensure('installed')
        end
      end

      it 'manages the server service by default' do
        is_expected.to contain_service('k3s').with(
          'ensure'   => 'running',
          'enable'   => true,
          'provider' => 'systemd',
        )
      end

      it 'renders the managed config file' do
        is_expected.to contain_file('/etc/rancher/k3s/config.yaml').with(
          'owner' => 'root',
          'group' => 'root',
          'mode'  => '0600',
        )
      end
    end
  end

  context 'when configuring an agent node' do
    let(:facts) do
      on_supported_os['ubuntu-22.04-x86_64']
    end

    let(:params) do
      {
        mode: 'agent',
        server: 'https://10.0.10.20:6443',
        token: Sensitive('super-secret-token'),
      }
    end

    it { is_expected.to compile.with_all_deps }

    it 'manages the agent service' do
      is_expected.to contain_service('k3s-agent').with(
        'ensure' => 'running',
        'enable' => true,
      )
    end

    it 'writes the agent server endpoint into the config file' do
      is_expected.to contain_file('/etc/rancher/k3s/config.yaml').with_content(
        %r{server: https://10.0.10.20:6443},
      )
    end
  end

  context 'when agent mode is selected without a server endpoint' do
    let(:facts) do
      on_supported_os['ubuntu-22.04-x86_64']
    end

    let(:params) do
      {
        mode: 'agent',
      }
    end

    it 'fails fast with a useful error' do
      expect { catalogue }.to raise_error(%r{parameter server is required when mode => agent})
    end
  end

  context 'when ensuring k3s is absent' do
    let(:facts) do
      on_supported_os['ubuntu-22.04-x86_64']
    end

    let(:params) do
      {
        ensure: 'absent',
      }
    end

    it { is_expected.to compile.with_all_deps }

    it 'declares the uninstall class instead of the install workflow' do
      is_expected.to contain_class('k3s::uninstall')
      is_expected.not_to contain_class('k3s::install')
      is_expected.not_to contain_class('k3s::config')
      is_expected.not_to contain_class('k3s::service')
    end
  end
end
