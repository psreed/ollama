# @summary Manages the Ollama LLM runtime.
#
# Installs Ollama via the official install script, optionally configures
# external network access by modifying the systemd unit file (Linux only),
# manages the system service, and pulls a configurable list of models once
# the service is running. Supports Linux (Debian/Ubuntu) and Windows.
#
# @param ensure
#   Controls whether Ollama is installed (`present`) or fully removed (`absent`).
#   When set to `absent`, the service is stopped and disabled, installation
#   artefacts are removed, and optionally all managed models are deleted first.
#
# @param manage_service
#   When true, the Ollama service is ensured running and enabled at boot.
#   When `ensure => absent`, the service is stopped and disabled before removal.
#
# @param enable_external_access
#   When true, adds `Environment="OLLAMA_HOST=0.0.0.0"` to the [Service]
#   section of the systemd unit file so Ollama listens on all interfaces.
#   Changing this parameter triggers a service restart.
#   Note: This parameter is only applied on Linux; it has no effect on Windows.
#
# @param ollama_port
#   TCP port Ollama listens on. Defaults to 11434, which is the official
#   default. It is strongly recommended NOT to change this unless you have a
#   specific reason; changing the port may break clients and tooling that
#   assume the standard port. On Linux the port is set via the OLLAMA_HOST
#   environment variable in the systemd unit file. On Windows it is set as a
#   machine-level OLLAMA_HOST environment variable via PowerShell.
#
# @param models
#   Array of Ollama model tags to pull after the service is running
#   (e.g. `['qwen3.5:4b', 'qwen3.5:9b', 'qwen3.5:latest']`). Downloads can
#   be large; Puppet's exec timeout is disabled for these resources.
#
# @param remove_models
#   When true and `ensure => absent`, each model listed in `$models` is removed
#   with `ollama rm` before the Ollama installation is deleted. Model removal
#   happens after the service is stopped (so the binary is still present to
#   run the command) but before files are cleaned up.
#
# @param purge_undefined_models
#   When true and `ensure => present`, any locally-installed Ollama model that
#   is NOT listed in `$models` will be removed with `ollama rm` on every Puppet
#   run. This enforces that only Puppet-defined models exist on the host.
#   Defaults to false to avoid accidental data loss.
#
# @param ollama_version
#   Version of Ollama to install. Defaults to `'latest'`, which runs the install
#   script without a version pin and installs only when the binary is absent.
#   Specify an explicit version string (e.g. `'0.5.7'`) to pin to that release;
#   Puppet will re-run the install script whenever the running version does not
#   match, allowing upgrades and downgrades.
#
class ollama (
  Enum['present', 'absent'] $ensure                  = 'present',
  Boolean                   $manage_service           = true,
  Boolean                   $enable_external_access   = false,
  Array[String[1]]          $models                   = [],
  Boolean                   $remove_models            = false,
  Boolean                   $purge_undefined_models   = false,
  String[1]                 $ollama_version           = 'latest',
  Integer[1, 65535]         $ollama_port              = 11434,
) {
  # Detect platform once; used throughout the class to select commands and
  # providers appropriate for each OS.
  $is_windows    = ($facts['os']['family'] == 'windows')
  $exec_provider = $is_windows ? { true => 'powershell', false => 'shell' }

  # Null-redirect suffix for unless/onlyif guards, per platform.
  $dev_null = $is_windows ? {
    true  => '2>$null',
    false => '>/dev/null 2>&1',
  }

  if $ensure == 'present' {
    # -------------------------------------------------------------------------
    # Install Ollama
    # -------------------------------------------------------------------------
    if $is_windows {
      # Windows: install via PowerShell. OLLAMA_VERSION env var pins the version.
      $install_command = $ollama_version ? {
        'latest' => 'irm https://ollama.com/install.ps1 | iex',
        default  => "\$env:OLLAMA_VERSION='${ollama_version}'; irm https://ollama.com/install.ps1 | iex",
      }
      # 'where.exe ollama' exits 0 when the binary is on PATH, 1 when absent.
      $install_unless = $ollama_version ? {
        'latest' => 'where.exe ollama',
        default  => "ollama --version 2>\$null | Select-String -Quiet '${ollama_version}'",
      }
    } else {
      # Linux: install via the official shell script.
      $install_command = $ollama_version ? {
        'latest' => 'curl -fsSL https://ollama.com/install.sh | sh',
        default  => "curl -fsSL https://ollama.com/install.sh | OLLAMA_VERSION=${ollama_version} sh",
      }
      # For a pinned version, re-run whenever the reported version differs.
      $install_unless = $ollama_version ? {
        'latest' => 'test -f /usr/local/bin/ollama',
        default  => "/usr/local/bin/ollama --version 2>/dev/null | grep -qF '${ollama_version}'",
      }
    }

    exec { 'install-ollama':
      command  => $install_command,
      provider => $exec_provider,
      unless   => $install_unless,
    }

    # -------------------------------------------------------------------------
    # Systemd unit file (Linux only)
    # -------------------------------------------------------------------------
    unless $is_windows {
      file { '/etc/systemd/system/ollama.service':
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => epp('ollama/ollama.service.epp', {
            'enable_external_access' => $enable_external_access,
            'ollama_port'            => $ollama_port,
        }),
        require => Exec['install-ollama'],
        notify  => Exec['ollama-daemon-reload'],
      }

      # Reload systemd whenever the unit file changes so the new configuration
      # is picked up before any service restart is attempted.
      exec { 'ollama-daemon-reload':
        command     => 'systemctl daemon-reload',
        path        => ['/bin', '/usr/bin'],
        refreshonly => true,
      }
    }

    # -------------------------------------------------------------------------
    # Service
    # -------------------------------------------------------------------------
    if $manage_service {
      if $is_windows {
        # On Windows, OLLAMA_HOST is set as a machine-level environment variable
        # so the service picks it up on restart. We always set it (even for the
        # default port) so the state is explicit and idempotent.
        $ollama_host_value = $enable_external_access ? {
          true  => "0.0.0.0:${ollama_port}",
          false => "127.0.0.1:${ollama_port}",
        }

        exec { 'ollama-set-host-windows':
          command  => "[System.Environment]::SetEnvironmentVariable('OLLAMA_HOST', '${ollama_host_value}', 'Machine')",
          provider => powershell,
          unless   => "[System.Environment]::GetEnvironmentVariable('OLLAMA_HOST', 'Machine') -eq '${ollama_host_value}'",
          require  => Exec['install-ollama'],
          notify   => Service['ollama'],
        }

        # On Windows there is no unit file or daemon-reload to subscribe to.
        service { 'ollama':
          ensure  => running,
          enable  => true,
          require => Exec['install-ollama'],
        }
      } else {
        service { 'ollama':
          ensure    => running,
          enable    => true,
          require   => [
            Exec['install-ollama'],
            File['/etc/systemd/system/ollama.service'],
          ],
          subscribe => Exec['ollama-daemon-reload'],
        }
      }
    }

    # -------------------------------------------------------------------------
    # Models
    # -------------------------------------------------------------------------
    if $manage_service {
      $require_before_models = Service['ollama']
    } elsif $is_windows {
      $require_before_models = Exec['install-ollama']
    } else {
      $require_before_models = File['/etc/systemd/system/ollama.service']
    }

    $models.each |String $model_name| {
      exec { "ollama-pull-${model_name}":
        command  => "ollama pull ${model_name}",
        provider => $exec_provider,
        unless   => "ollama show ${model_name} ${dev_null}",
        timeout  => 0,
        require  => $require_before_models,
      }
    }

    # -------------------------------------------------------------------------
    # Purge undefined models
    # -------------------------------------------------------------------------
    if $purge_undefined_models {
      $defined_model_names = $models

      $purge_require = $manage_service ? {
        true  => Service['ollama'],
        false => $is_windows ? {
          true  => Exec['install-ollama'],
          false => File['/etc/systemd/system/ollama.service'],
        },
      }

      if $is_windows {
        # Build a PowerShell array literal from the Puppet-defined model list.
        $defined_list_ps = join($defined_model_names, "','")
        exec { 'ollama-purge-undefined-models':
          command  => "\$defined = @('${defined_list_ps}'); ollama list | Select-Object -Skip 1 | ForEach-Object { \$name = (\$_ -split '\\s+')[0]; if (\$name -and \$defined -notcontains \$name) { ollama rm \$name } }",
          provider => powershell,
          require  => $purge_require,
        }
      } else {
        # Build a newline-separated list for exact grep matching.
        $defined_list = join($defined_model_names, '\n')
        exec { 'ollama-purge-undefined-models':
          command  => "ollama list | awk 'NR>1 {print \$1}' | while IFS= read -r _model; do printf '${defined_list}\\n' | grep -qxF \"\$_model\" || ollama rm \"\$_model\"; done",
          provider => shell,
          require  => $purge_require,
        }
      }
    }
  } else {
    # -------------------------------------------------------------------------
    # Removal (ensure => absent)
    # -------------------------------------------------------------------------
    if $is_windows {
      # Order: stop service -> remove models -> remove installation directory.

      if $manage_service {
        service { 'ollama':
          ensure => stopped,
          enable => false,
          before => Exec['ollama-remove-installation'],
        }
      }

      if $remove_models and !$models.empty {
        $rm_require = $manage_service ? {
          true  => Service['ollama'],
          false => [],
        }

        $models.each |String $model_name| {
          exec { "ollama-rm-${model_name}":
            command  => "ollama rm ${model_name}",
            provider => powershell,
            onlyif   => "ollama show ${model_name} 2>\$null",
            require  => $rm_require,
            before   => Exec['ollama-remove-installation'],
          }
        }
      }

      # Remove Ollama from all known Windows installation locations.
      # Uses a single-quoted Puppet string so PowerShell variables are
      # passed through without Puppet interpolation.
      exec { 'ollama-remove-installation':
        command  => '$paths = @("$env:LOCALAPPDATA\Programs\Ollama", "$env:ProgramFiles\Ollama"); foreach ($p in $paths) { if (Test-Path $p) { Remove-Item -Recurse -Force $p } }',
        provider => powershell,
        onlyif   => 'where.exe ollama',
      }
    } else {
      # Linux removal order:
      # stop service -> remove models -> unit file -> daemon-reload -> binary

      if $manage_service {
        service { 'ollama':
          ensure => stopped,
          enable => false,
          before => File['/etc/systemd/system/ollama.service'],
        }
      }

      if $remove_models and !$models.empty {
        $rm_require = $manage_service ? {
          true  => Service['ollama'],
          false => [],
        }

        $models.each |String $model_name| {
          exec { "ollama-rm-${model_name}":
            command  => "ollama rm ${model_name}",
            provider => shell,
            onlyif   => "ollama show ${model_name} >/dev/null 2>&1",
            require  => $rm_require,
            before   => File['/etc/systemd/system/ollama.service'],
          }
        }
      }

      file { '/etc/systemd/system/ollama.service':
        ensure => absent,
        notify => Exec['ollama-daemon-reload'],
      }

      exec { 'ollama-daemon-reload':
        command     => 'systemctl daemon-reload',
        path        => ['/bin', '/usr/bin'],
        refreshonly => true,
      }

      file { '/usr/local/bin/ollama':
        ensure  => absent,
        require => File['/etc/systemd/system/ollama.service'],
      }
    }
  }
}
