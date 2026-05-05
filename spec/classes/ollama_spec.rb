# frozen_string_literal: true

require 'spec_helper'

describe 'ollama' do
  # ---------------------------------------------------------------------------
  # Linux (Debian 12)
  # ---------------------------------------------------------------------------
  context 'on Debian 12 (Linux)' do
    let(:facts) do
      {
        os: {
          family:  'Debian',
          name:    'Debian',
          release: { major: '12', full: '12.0' },
        },
      }
    end

    # ---- defaults ------------------------------------------------------------
    context 'with default parameters' do
      it { is_expected.to compile.with_all_deps }

      it 'installs ollama via the shell script' do
        is_expected.to contain_exec('install-ollama').with(
          provider: 'shell',
          unless:   'test -f /usr/local/bin/ollama',
        )
        is_expected.to contain_exec('install-ollama').with(
          command: 'curl -fsSL https://ollama.com/install.sh | sh',
        )
      end

      it 'manages the systemd unit file' do
        is_expected.to contain_file('/etc/systemd/system/ollama.service').with(
          ensure: 'file',
          owner:  'root',
          group:  'root',
          mode:   '0644',
        )
      end

      it 'does not set OLLAMA_HOST in the unit file by default' do
        is_expected.to contain_file('/etc/systemd/system/ollama.service').without_content(
          %r{OLLAMA_HOST},
        )
      end

      it 'creates a daemon-reload exec' do
        is_expected.to contain_exec('ollama-daemon-reload').with(
          command:     'systemctl daemon-reload',
          refreshonly: true,
        )
      end

      it 'manages the ollama service as running and enabled' do
        is_expected.to contain_service('ollama').with(
          ensure: 'running',
          enable: true,
        )
      end

      it 'does not pull any models' do
        is_expected.not_to contain_exec('ollama-pull-qwen3.5:4b')
      end

      it 'does not create a purge exec' do
        is_expected.not_to contain_exec('ollama-purge-undefined-models')
      end
    end

    # ---- enable_external_access ----------------------------------------------
    context 'with enable_external_access => true' do
      let(:params) { { enable_external_access: true } }

      it 'sets OLLAMA_HOST=0.0.0.0 in the unit file' do
        is_expected.to contain_file('/etc/systemd/system/ollama.service').with_content(
          %r{Environment="OLLAMA_HOST=0\.0\.0\.0"},
        )
      end
    end

    # ---- custom port without external access ---------------------------------
    context 'with ollama_port => 9999 and enable_external_access => false' do
      let(:params) { { ollama_port: 9999 } }

      it 'sets OLLAMA_HOST=127.0.0.1:9999 in the unit file' do
        is_expected.to contain_file('/etc/systemd/system/ollama.service').with_content(
          %r{Environment="OLLAMA_HOST=127\.0\.0\.1:9999"},
        )
      end
    end

    # ---- custom port with external access ------------------------------------
    context 'with ollama_port => 9999 and enable_external_access => true' do
      let(:params) { { ollama_port: 9999, enable_external_access: true } }

      it 'sets OLLAMA_HOST=0.0.0.0:9999 in the unit file' do
        is_expected.to contain_file('/etc/systemd/system/ollama.service').with_content(
          %r{Environment="OLLAMA_HOST=0\.0\.0\.0:9999"},
        )
      end
    end

    # ---- version pinning -----------------------------------------------------
    context 'with ollama_version => 0.5.7' do
      let(:params) { { ollama_version: '0.5.7' } }

      it 'installs the pinned version' do
        is_expected.to contain_exec('install-ollama').with(
          command: 'curl -fsSL https://ollama.com/install.sh | OLLAMA_VERSION=0.5.7 sh',
          unless:  "/usr/local/bin/ollama --version 2>/dev/null | grep -qF '0.5.7'",
        )
      end
    end

    # ---- model management ---------------------------------------------------
    context 'with models defined' do
      let(:params) do
        {
          models: ['qwen3.5:4b', 'qwen3.5:latest'],
        }
      end

      it 'pulls each declared model' do
        is_expected.to contain_exec('ollama-pull-qwen3.5:4b').with(
          command:  'ollama pull qwen3.5:4b',
          provider: 'shell',
          unless:   'ollama show qwen3.5:4b >/dev/null 2>&1',
          timeout:  0,
        )
        is_expected.to contain_exec('ollama-pull-qwen3.5:latest').with(
          command: 'ollama pull qwen3.5:latest',
        )
      end

      it 'sets HOME on each pull exec' do
        is_expected.to contain_exec('ollama-pull-qwen3.5:4b').with(
          environment: ['HOME=/root'],
        )
      end
    end

    # ---- ollama_home --------------------------------------------------------
    context 'with ollama_home => /home/ollama' do
      let(:params) do
        {
          models:      ['qwen3.5:4b'],
          ollama_home: '/home/ollama',
        }
      end

      it 'sets the custom HOME on pull execs' do
        is_expected.to contain_exec('ollama-pull-qwen3.5:4b').with(
          environment: ['HOME=/home/ollama'],
        )
      end
    end

    # ---- purge_undefined_models ---------------------------------------------
    context 'with purge_undefined_models => true' do
      let(:params) do
        {
          purge_undefined_models: true,
          models:                 ['qwen3.5:4b'],
        }
      end

      it 'creates the purge exec' do
        is_expected.to contain_exec('ollama-purge-undefined-models').with(
          provider: 'shell',
        )
      end

      it 'sets HOME on the purge exec' do
        is_expected.to contain_exec('ollama-purge-undefined-models').with(
          environment: ['HOME=/root'],
        )
      end
    end

    # ---- manage_service => false --------------------------------------------
    context 'with manage_service => false' do
      let(:params) { { manage_service: false } }

      it 'does not manage the service resource' do
        is_expected.not_to contain_service('ollama')
      end
    end

    # ---- ensure => absent ---------------------------------------------------
    context 'with ensure => absent' do
      let(:params) { { ensure: 'absent', manage_service: true } }

      it { is_expected.to compile.with_all_deps }

      it 'stops and disables the service' do
        is_expected.to contain_service('ollama').with(
          ensure: 'stopped',
          enable: false,
        )
      end

      it 'removes the unit file' do
        is_expected.to contain_file('/etc/systemd/system/ollama.service').with(
          ensure: 'absent',
        )
      end

      it 'removes the binary' do
        is_expected.to contain_file('/usr/local/bin/ollama').with(
          ensure: 'absent',
        )
      end

      it 'does not install ollama' do
        is_expected.not_to contain_exec('install-ollama')
      end
    end

    # ---- ensure => absent with remove_models --------------------------------
    context 'with ensure => absent and remove_models => true' do
      let(:params) do
        {
          ensure:        'absent',
          manage_service: true,
          remove_models: true,
          models:        ['qwen3.5:4b', 'qwen3.5:9b'],
        }
      end

      it 'removes each listed model before uninstalling' do
        is_expected.to contain_exec('ollama-rm-qwen3.5:4b').with(
          command:  'ollama rm qwen3.5:4b',
          provider: 'shell',
          onlyif:   'ollama show qwen3.5:4b >/dev/null 2>&1',
        )
        is_expected.to contain_exec('ollama-rm-qwen3.5:9b').with(
          command: 'ollama rm qwen3.5:9b',
        )
      end

      it 'sets HOME on rm execs' do
        is_expected.to contain_exec('ollama-rm-qwen3.5:4b').with(
          environment: ['HOME=/root'],
        )
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Windows
  # ---------------------------------------------------------------------------
  context 'on Windows Server 2022' do
    let(:facts) do
      {
        os: {
          family:  'windows',
          name:    'windows',
          release: { major: '2022', full: '2022' },
        },
      }
    end

    context 'with default parameters' do
      it { is_expected.to compile.with_all_deps }

      it 'installs ollama via PowerShell' do
        is_expected.to contain_exec('install-ollama').with(
          provider: 'powershell',
          command:  'irm https://ollama.com/install.ps1 | iex',
          unless:   'where.exe ollama',
        )
      end

      it 'does not create the systemd unit file' do
        is_expected.not_to contain_file('/etc/systemd/system/ollama.service')
      end

      it 'does not create a daemon-reload exec' do
        is_expected.not_to contain_exec('ollama-daemon-reload')
      end

      it 'manages the ollama service' do
        is_expected.to contain_service('ollama').with(
          ensure: 'running',
          enable: true,
        )
      end

      it 'sets the OLLAMA_HOST machine environment variable' do
        is_expected.to contain_exec('ollama-set-host-windows').with(
          provider: 'powershell',
        )
      end
    end

    context 'with ollama_version => 0.5.7' do
      let(:params) { { ollama_version: '0.5.7' } }

      it 'installs the pinned version via PowerShell' do
        is_expected.to contain_exec('install-ollama').with(
          command: "$env:OLLAMA_VERSION='0.5.7'; irm https://ollama.com/install.ps1 | iex",
        )
      end
    end

    context 'with models defined' do
      let(:params) { { models: ['qwen3.5:4b'] } }

      it 'pulls models via powershell provider' do
        is_expected.to contain_exec('ollama-pull-qwen3.5:4b').with(
          command:  'ollama pull qwen3.5:4b',
          provider: 'powershell',
        )
      end

      it 'does not set HOME on Windows pull execs' do
        is_expected.to contain_exec('ollama-pull-qwen3.5:4b').with(
          environment: [],
        )
      end
    end

    context 'with ensure => absent' do
      let(:params) { { ensure: 'absent', manage_service: true } }

      it { is_expected.to compile.with_all_deps }

      it 'stops and disables the service' do
        is_expected.to contain_service('ollama').with(
          ensure: 'stopped',
          enable: false,
        )
      end

      it 'removes the installation directory' do
        is_expected.to contain_exec('ollama-remove-installation').with(
          provider: 'powershell',
          onlyif:   'where.exe ollama',
        )
      end

      it 'does not remove the linux binary' do
        is_expected.not_to contain_file('/usr/local/bin/ollama')
      end
    end

    context 'with ensure => absent and remove_models => true' do
      let(:params) do
        {
          ensure:        'absent',
          manage_service: true,
          remove_models: true,
          models:        ['qwen3.5:4b'],
        }
      end

      it 'removes models via PowerShell provider' do
        is_expected.to contain_exec('ollama-rm-qwen3.5:4b').with(
          command:  'ollama rm qwen3.5:4b',
          provider: 'powershell',
        )
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Parameter validation
  # ---------------------------------------------------------------------------
  context 'parameter validation' do
    let(:facts) do
      {
        os: {
          family:  'Debian',
          name:    'Debian',
          release: { major: '12', full: '12.0' },
        },
      }
    end

    it 'rejects an invalid ensure value' do
      expect do
        catalogue # force compilation
      end.not_to raise_error
    end

    context 'with ensure => invalid' do
      let(:params) { { ensure: 'invalid' } }

      it { is_expected.not_to compile }
    end

    context 'with ollama_port => 0' do
      let(:params) { { ollama_port: 0 } }

      it { is_expected.not_to compile }
    end

    context 'with ollama_port => 65536' do
      let(:params) { { ollama_port: 65_536 } }

      it { is_expected.not_to compile }
    end
  end
end
