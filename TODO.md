- Add `ensure => absent` capability which will remove the service and Ollama installation
- Add ability to also remove all models when `ensure => absent` is used, which should remove the models before the installation (as it will likely use `ollama` commands)
- Add ability to purge undefined modules using a `purge_undefined_models` flag, which defaults to `false`
- Add the ability to select the version for the Ollama installation as a manafest parameter `ollama_version`, default to `latest` which will omit the selection. The version is installed using `curl -fsSL https://ollama.com/install.sh | OLLAMA_VERSION=0.5.7 sh` vs a latest install which would simple be curl -fsSL https://ollama.com/install.sh | sh
- Support Windows based install and removal (command for install is `$env:OLLAMA_VERSION="0.5.7"; irm https://ollama.com/install.ps1 | iex`)
- Add ability to change the service away from the default port via manifest parameter (but recommend in comments not to change it)


Notes:
- Models are removed with `ollama rm <model_name>`
- Models are added with `ollama pull <model_name>`
- Ollama default port is TCP 11434
