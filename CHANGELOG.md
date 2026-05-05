# Changelog

All notable changes to this project will be documented in this file.

## Release 1.0.2 (2026-05-05)

**Features**

- Added `enable_flash_attention` parameter (`Boolean`, default `true`). When
  `true`, sets `Environment="OLLAMA_FLASH_ATTENTION=1"` in the systemd unit
  file, enabling flash attention for supported models. Changing this parameter
  triggers a service restart. This parameter has no effect on Windows.
- Added `modelfiles` parameter (`Hash[String[1], String[1]]`, default `{}`). Keys
  are custom model names/tags and values are the raw Modelfile content. For each
  entry, a file named `Modelfile-<name>` is written to `$modelfile_dir` and
  `ollama create "<name>" -f <file>` is run once the service is available. The
  model is automatically re-created whenever its Modelfile content changes. This
  parameter has no effect on Windows.
- Added `modelfile_dir` parameter (`String[1]`, default `'/opt/ollama-models'`).
  Directory where Modelfiles are stored on disk; created automatically when
  `$modelfiles` is non-empty. Has no effect on Windows.

**Changes**

- Updated `spec/classes/ollama_spec.rb` with additional unit tests covering:
  - `enable_flash_attention` defaults to `true` (asserts `OLLAMA_FLASH_ATTENTION=1`
    present in the systemd unit file)
  - `enable_flash_attention => false` (asserts env var is absent from unit file)
  - `modelfiles` defined: Modelfile directory resource, Modelfile file resource
    with content, `ollama-create-*` exec (idempotency guard, `HOME` env, timeout),
    and `ollama-recreate-*` exec (refreshonly behaviour)
  - `modelfiles` empty (default): asserts modelfile directory is not created
  - Windows default parameters: asserts no modelfile resources are created
- Fixed Rubocop `BlockDelimiters` convention in `spec/classes/ollama_spec.rb`:
  replaced multi-line `do...end` block chained with `.not_to` with a single-line
  `{ }` block (`expect { catalogue }.not_to raise_error`).
- Added `spec/spec_helper_local.rb` with a stub `powershell` exec provider so
  that Windows-targeted `Exec` resources with `provider => 'powershell'` compile
  correctly on Linux CI runners where the provider is not available.

---

## Release 1.0.1 (2026-05-04)

**Changes**

- Rewrote README.md with full module documentation, parameter reference table,
  Hiera example, common usage examples, affected resource tables, requirements,
  and limitations sections.
- Added `spec/classes/ollama_spec.rb` with rspec-puppet unit tests covering:
  - Default parameter behaviour on Linux (Debian 12) and Windows (Server 2022)
  - `enable_external_access`, `ollama_port`, and combined port + access scenarios
  - Version pinning install command and idempotency guard
  - Model pull execs including `HOME` environment injection via `ollama_home`
  - `purge_undefined_models` exec creation and environment
  - `manage_service => false` skips the service resource
  - `ensure => absent` removal ordering (service, unit file, binary on Linux;
    service and installation directory on Windows)
  - `remove_models => true` under `ensure => absent` on both platforms
  - Parameter validation: rejects invalid `ensure` values and out-of-range
    `ollama_port` values

---

## Release 1.0.0 (2026-05-04)

**Features**

- Initial functional release of the `psreed-ollama` module.
- Install Ollama on Linux via `curl -fsSL https://ollama.com/install.sh | sh`
  and on Windows via `irm https://ollama.com/install.ps1 | iex`.
- `ollama_version` parameter to pin a specific release; idempotent re-install
  when the running binary version does not match.
- `manage_service` parameter to control the `ollama` systemd (Linux) or
  Windows service, including enable/disable on boot.
- `enable_external_access` parameter to bind Ollama to `0.0.0.0` instead of
  loopback only (Linux: systemd unit `OLLAMA_HOST`; Windows: machine-level
  environment variable).
- `ollama_port` parameter to change the listening port away from the default
  TCP 11434 (discouraged; documented warning included).
- `ollama_home` parameter to inject a `HOME` environment variable into all
  `ollama` CLI exec resources, resolving model pull failures when Puppet runs
  without a login shell.
- `models` parameter (`Array[String[1]]`) to declare which Ollama model tags
  should be pulled; each model is idempotently managed with `ollama pull`.
- `purge_undefined_models` parameter to remove any locally-installed model not
  declared in `$models` on every Puppet run.
- `ensure => absent` support: stops and disables the service, removes the
  systemd unit file (Linux), triggers `daemon-reload`, and deletes the binary
  (Linux) or installation directory (Windows).
- `remove_models` parameter to run `ollama rm` on all managed models before
  uninstalling, ensuring the CLI is still available when models are removed.
- Cross-platform support declared for Debian 12/13, Ubuntu 24.04/26.04,
  Windows Server 2019/2022, and Windows 11.
- Hiera Automatic Parameter Lookup (APL) for all parameters; `data/common.yaml`
  intentionally left empty for use with Puppet Enterprise node groups.

**Known Issues**

- `enable_external_access` is Linux-only via the systemd unit file. On Windows
  the bind address is always set through the `OLLAMA_HOST` machine environment
  variable regardless of this parameter.
- Model downloads can be several GB; exec timeout is disabled (`timeout => 0`)
  for `ollama pull` resources.

