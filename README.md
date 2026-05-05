# psreed-ollama

Puppet module for installing and managing [Ollama](https://ollama.com), the local LLM runtime. Supports Debian/Ubuntu (Linux) and Windows.

## Table of Contents

1. [Description](#description)
1. [Setup](#setup)
    * [What ollama affects](#what-ollama-affects)
    * [Requirements](#requirements)
    * [Beginning with ollama](#beginning-with-ollama)
1. [Usage](#usage)
    * [Hiera (recommended)](#hiera-recommended)
    * [Common examples](#common-examples)
1. [Reference](#reference)
1. [Limitations](#limitations)

## Description

This module installs Ollama via the official install script (Linux) or PowerShell installer (Windows), manages the systemd service (Linux) or Windows service, optionally configures external network access and a custom port, and enforces a defined set of models via `ollama pull` / `ollama rm`.

Key features:

- Install or remove Ollama, with optional version pinning
- Manage the `ollama` service (enable, disable, restart on config change)
- Expose Ollama on all interfaces and/or a custom port
- Declare which models should be present; optionally purge everything else
- Full `ensure => absent` support including model cleanup before uninstall
- Cross-platform: Linux (Debian/Ubuntu) and Windows

## Setup

### What ollama affects

**Linux**

| Resource | Detail |
|---|---|
| `/usr/local/bin/ollama` | Binary installed by the official install script |
| `/etc/systemd/system/ollama.service` | Systemd unit file (managed by this module) |
| `systemd daemon-reload` | Triggered whenever the unit file changes |
| `ollama` service | Managed via Puppet `service` resource |
| `~/.ollama/models` (under `$ollama_home`) | Model storage directory used by the CLI |
| `$modelfile_dir` (default `/opt/ollama-models`) | Directory where Modelfiles are written when `$modelfiles` is non-empty |

**Windows**

| Resource | Detail |
|---|---|
| Ollama installation directory | `%LOCALAPPDATA%\Programs\Ollama` or `%ProgramFiles%\Ollama` |
| `OLLAMA_HOST` machine env var | Set via PowerShell to control bind address and port |
| `ollama` Windows service | Managed via Puppet `service` resource |

### Requirements

- Puppet >= 7.24
- Linux targets: `curl` must be available; `systemd` is required for service management
- Windows targets: PowerShell execution policy must permit running remote scripts (`irm … | iex`)
- The node running Puppet must be able to reach `ollama.com` for installation and model downloads

### Beginning with ollama

Classify a node with the `ollama` class. All parameters have defaults and are intended to be driven through Hiera or Puppet Enterprise node groups:

```puppet
include ollama
```

To install a specific version with a set of models:

```puppet
class { 'ollama':
  ollama_version => '0.5.7',
  models         => ['qwen3.5:4b', 'qwen3.5:latest'],
}
```

## Usage

### Hiera (recommended)

Set these keys in your Hiera data (e.g. a PE node group or `common.yaml`):

```yaml
ollama::ensure: 'present'
ollama::manage_service: true
ollama::enable_external_access: false
ollama::enable_flash_attention: true
ollama::ollama_version: 'latest'
ollama::ollama_port: 11434
ollama::ollama_home: '/root'
ollama::remove_models: false
ollama::purge_undefined_models: false
ollama::modelfile_dir: '/opt/ollama-models'
ollama::models:
  - 'qwen3.5:4b'
  - 'qwen3.5:9b'
  - 'qwen3.5:latest'
ollama::modelfiles:
  'Qwen3.5:9b-8k': |
    FROM qwen3.5:9b
    PARAMETER num_ctx 8192
    SYSTEM """
    You are a senior software engineer. Provide concise, efficient code and explain complex logic clearly.
    """
  'Qwen3.5:9b-16k-kvq4': |
    FROM qwen3.5:9b
    PARAMETER num_ctx 16384
    PARAMETER kv_cache_type q4_0
    SYSTEM """
    You are a senior software engineer. Provide concise, efficient code and explain complex logic clearly.
    """
```

### Common examples

**Expose Ollama on all interfaces (default port):**

```puppet
class { 'ollama':
  enable_external_access => true,
}
```

**Enable flash attention** — improves inference performance for supported models (Linux only):

```puppet
class { 'ollama':
  enable_flash_attention => true,
}
```

**Pin to a specific version** — Puppet will re-run the installer if the running binary differs:

```puppet
class { 'ollama':
  ollama_version => '0.5.7',
}
```

**Custom port** — not recommended unless you have a specific reason; changing the port may break clients that assume TCP 11434:

```puppet
class { 'ollama':
  enable_external_access => true,
  ollama_port            => 9999,
}
```

**Enforce only Puppet-defined models** — any model pulled outside of Puppet will be removed on the next run:

```puppet
class { 'ollama':
  purge_undefined_models => true,
  models                 => ['qwen3.5:4b', 'qwen3.5:9b', 'qwen3.5:latest'],
}
```

**Completely remove Ollama, including models:**

```puppet
class { 'ollama':
  ensure         => absent,
  manage_service => true,
  remove_models  => true,
  models         => ['qwen3.5:4b', 'qwen3.5:9b', 'qwen3.5:latest'],
}
```

**Fix missing `$HOME` when Puppet agent runs without a login shell (Linux):**

```puppet
class { 'ollama':
  ollama_home => '/root',
}
```

**Create custom models from Modelfiles** — base models should also be listed in `$models` to ensure they are pulled first (Linux only):

```puppet
class { 'ollama':
  models     => ['qwen3.5:9b'],
  modelfiles => {
    'Qwen3.5:9b-16k-kvq4' => @("MODELFILE"),
      FROM qwen3.5:9b
      PARAMETER num_ctx 16384
      PARAMETER kv_cache_type q4_0
      SYSTEM """
      You are a senior software engineer.
      Provide concise, efficient code and explain complex logic clearly.
      """
      | MODELFILE
  },
}
```

Each Modelfile is written to `$modelfile_dir/Modelfile-<name>` (e.g.
`/opt/ollama-models/Modelfile-Qwen3.5:9b-16k-kvq4`) and `ollama create` is
run. Subsequent Puppet runs re-create the model only if the Modelfile content
changes.

## Reference

### Class: `ollama`

#### Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `ensure` | `Enum['present','absent']` | `'present'` | Install (`present`) or fully remove (`absent`) Ollama |
| `manage_service` | `Boolean` | `true` | Manage the `ollama` service resource |
| `enable_external_access` | `Boolean` | `false` | Bind Ollama to `0.0.0.0` instead of loopback only (Linux: systemd unit; Windows: `OLLAMA_HOST` machine env var) |
| `enable_flash_attention` | `Boolean` | `true` | Set `OLLAMA_FLASH_ATTENTION=1` in the systemd unit file (Linux only). Enables flash attention for supported models; changing this triggers a service restart |
| `ollama_port` | `Integer[1,65535]` | `11434` | TCP port Ollama listens on. Changing this is discouraged |
| `ollama_version` | `String[1]` | `'latest'` | Version to install. Use `'latest'` for the most recent release or a specific string like `'0.5.7'` to pin |
| `ollama_home` | `String[1]` | `'/root'` | `HOME` environment variable injected into all `ollama` CLI exec resources (Linux only). Required when the Puppet agent runs without a login shell |
| `models` | `Array[String[1]]` | `[]` | List of Ollama model tags to ensure are pulled (e.g. `['qwen3.5:4b']`) |
| `remove_models` | `Boolean` | `false` | When `ensure => absent`, remove all listed models before uninstalling |
| `purge_undefined_models` | `Boolean` | `false` | Remove any locally-installed model not listed in `$models` on every Puppet run |
| `modelfiles` | `Hash[String[1],String[1]]` | `{}` | Hash of custom model name → Modelfile content. Writes `Modelfile-<name>` to `$modelfile_dir` and runs `ollama create` (Linux only). Model is re-created automatically when content changes |
| `modelfile_dir` | `String[1]` | `'/opt/ollama-models'` | Directory where Modelfiles are stored on disk (Linux only). Created automatically when `$modelfiles` is non-empty |

## Limitations

- `enable_external_access` is only applied on Linux via the systemd unit file. On Windows, the bind address is always derived from `$ollama_port` and set via the `OLLAMA_HOST` machine environment variable.
- Model downloads (`ollama pull`) can be very large (several GB). The `exec` timeout is disabled (`timeout => 0`) for these resources.
- `purge_undefined_models` runs on every Puppet catalog application; ensure your `$models` list is complete before enabling it.
- `modelfiles` and `modelfile_dir` are Linux-only; they have no effect on Windows. Custom models created via Modelfiles are not removed on `ensure => absent` — delete them manually with `ollama rm` before or after removal if needed.
- Modelfile names may contain `:` characters (valid on Linux filesystems). Avoid characters that are invalid in file paths or in `ollama` model name syntax.
- The Windows removal exec targets `%LOCALAPPDATA%\Programs\Ollama` and `%ProgramFiles%\Ollama`. Models stored in a non-standard location will not be removed.
- Tested on Debian 12/13, Ubuntu 24.04/26.04, Windows Server 2019/2022, and Windows 11.

