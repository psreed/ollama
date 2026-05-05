# @summary Manages the Ollama LLM runtime.
#
# Installs Ollama via the official install script, optionally configures
# external network access by modifying the systemd unit file, manages the
# systemd service, and pulls a configurable list of models once the service
# is running.
#
# @param manage_service
#   When true, the ollama systemd service is ensured running and enabled at boot.
#
# @param enable_external_access
#   When true, adds `Environment="OLLAMA_HOST=0.0.0.0"` to the [Service]
#   section of the systemd unit file so Ollama listens on all interfaces.
#   Changing this parameter triggers a service restart.
#
# @param models
#   Array of model hashes to pull after the service is running.
#   Each hash must contain at least a 'name' key with the Ollama model tag
#   (e.g. `{ 'name' => 'qwen3.5:4b' }`). Downloads can be large; Puppet's
#   exec timeout is disabled for these resources.
#
class ollama (
  Boolean     $manage_service         = true,
  Boolean     $enable_external_access = false,
  Array[Hash] $models                 = [],
) {
  # ---------------------------------------------------------------------------
  # Install Ollama
  # ---------------------------------------------------------------------------
  exec { 'install-ollama':
    command  => 'curl -fsSL https://ollama.com/install.sh | sh',
    provider => shell,
    creates  => '/usr/local/bin/ollama',
  }

  # ---------------------------------------------------------------------------
  # Systemd unit file
  # ---------------------------------------------------------------------------
  file { '/etc/systemd/system/ollama.service':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('ollama/ollama.service.epp', {
        'enable_external_access' => $enable_external_access,
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

  # ---------------------------------------------------------------------------
  # Service
  # ---------------------------------------------------------------------------
  if $manage_service {
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

  # ---------------------------------------------------------------------------
  # Models
  # ---------------------------------------------------------------------------
  # Require the service when it is managed so models are pulled only after
  # Ollama is confirmed running; otherwise simply require the unit file.
  $require_before_models = $manage_service ? {
    true  => Service['ollama'],
    false => File['/etc/systemd/system/ollama.service'],
  }

  $models.each |Hash $model| {
    $model_name = $model['name']

    exec { "ollama-pull-${model_name}":
      command  => "ollama pull ${model_name}",
      provider => shell,
      unless   => "ollama show ${model_name} > /dev/null 2>&1",
      timeout  => 0,
      require  => $require_before_models,
    }
  }
}
