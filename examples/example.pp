# Example: Hiera data (e.g. in common.yaml or a PE node group):
#
# ollama::ensure: 'present'
# ollama::manage_service: true
# ollama::enable_external_access: false
# ollama::remove_models: false
# ollama::purge_undefined_models: false
# ollama::ollama_version: 'latest'
# ollama::ollama_port: 11434
# ollama::models:
#   - 'qwen3.5:4b'
#   - 'qwen3.5:9b'
#   - 'qwen3.5:latest'

# Example: rely entirely on Hiera for all parameter values (recommended).
include ollama

# Example: override specific parameters at the class declaration level,
# bypassing Hiera for those keys.
#
# class { 'ollama':
#   manage_service         => true,
#   enable_external_access => true,
#   models                 => [
#     'qwen3.5:4b',
#     'qwen3.5:9b',
#     'qwen3.5:latest',
#   ],
# }

# Example: pin Ollama to a specific version. Puppet will re-run the install
# script if the running binary reports a different version.
#
# class { 'ollama':
#   ollama_version => '0.5.7',
# }

# Example: change the listening port. NOTE: it is strongly recommended to
# leave this at the default (11434). Changing it may break clients, tools,
# and integrations that assume the standard Ollama port.
#
# class { 'ollama':
#   enable_external_access => true,
#   ollama_port            => 9999,
# }

# Example: remove Ollama, stopping the service and also removing all models
# listed in the $models parameter before the binary is deleted.
#
# class { 'ollama':
#   ensure         => absent,
#   manage_service => true,
#   remove_models  => true,
#   models         => [
#     'qwen3.5:4b',
#     'qwen3.5:9b',
#     'qwen3.5:latest',
#   ],
# }

# Example: enforce that only Puppet-defined models exist; any model not in the
# list (e.g. pulled manually) will be removed on every Puppet run.
#
# class { 'ollama':
#   purge_undefined_models => true,
#   models                 => [
#     'qwen3.5:4b',
#     'qwen3.5:9b',
#     'qwen3.5:latest',
#   ],
# }

# Example: Windows install, pinned version, with model management.
# On Windows there is no systemd unit file; enable_external_access has no
# effect and should be left false. The service is the Windows 'ollama' service.
#
# class { 'ollama':
#   ollama_version => '0.5.7',
#   manage_service => true,
#   models         => [
#     'qwen3.5:4b',
#     'qwen3.5:latest',
#   ],
# }

# Example: remove Ollama on Windows, cleaning up all managed models first.
#
# class { 'ollama':
#   ensure         => absent,
#   manage_service => true,
#   remove_models  => true,
#   models         => [
#     'qwen3.5:4b',
#     'qwen3.5:9b',
#     'qwen3.5:latest',
#   ],
# }
