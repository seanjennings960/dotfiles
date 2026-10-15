#!/usr/bin/env zsh

UV_VERSION=0.13.1
PYTHON_VERSION=3.11.17

# Source this file from Zsh to activate the repository's host-side dev CLI.
if [ -z "${ZSH_VERSION:-}" ]; then
  printf '%s\n' 'activate.sh requires Zsh. Run: zsh, then source ./activate.sh' >&2
  return 1 2>/dev/null || exit 1
fi

if [[ ${ZSH_EVAL_CONTEXT:-} != *:file* ]]; then
  print -u2 -- "Source this script from Zsh: source ${0:A:h}/activate.sh"
  exit 1
fi

function _dotfiles_dev_log {
  # Keep diagnostics on stderr so callers can reserve stdout for command output.
  print -u2 -- "$*"
}

function _dotfiles_dev_find_python {
  local python_dir candidate
  local -a candidates
  python_dir="$1"
  candidates=("$python_dir"/cpython-${PYTHON_VERSION}*/bin/python3.11(N))
  for candidate in "${candidates[@]}"; do
    if "$candidate" -c 'import sys; assert sys.version_info >= (3, 11)' 2>/dev/null; then
      print -r -- "$candidate"
      return 0
    fi
  done
  return 1
}

function _dotfiles_dev_install_uv {
  local tools_dir uv_cmd installed_version
  tools_dir="$1"
  uv_cmd="$tools_dir/uv"
  if [[ -x "$uv_cmd" ]]; then
    installed_version=$("$uv_cmd" --version 2>/dev/null) || installed_version=""
    if [[ "$installed_version" == "uv $UV_VERSION" ]]; then
      return 0
    fi
  fi
  if ! command -v curl >/dev/null || ! command -v sh >/dev/null; then
    _dotfiles_dev_log "Bootstrapping the development tools requires curl and sh on PATH."
    return 1
  fi
  if ! command mkdir -p "$tools_dir"; then
    _dotfiles_dev_log "Could not create $tools_dir."
    return 1
  fi
  print -- "Installing repository-local uv $UV_VERSION"
  if ! command curl --fail --silent --show-error --location https://astral.sh/uv/install.sh |
    UV_VERSION="$UV_VERSION" UV_INSTALL_DIR="$tools_dir" UV_NO_MODIFY_PATH=1 UV_NO_INSTALLER_METADATA=1 command sh; then
    _dotfiles_dev_log "Could not install uv. Check network access and retry."
    return 1
  fi
  if [[ ! -x "$uv_cmd" ]]; then
    _dotfiles_dev_log "The uv installer completed without creating $uv_cmd."
    return 1
  fi
  installed_version=$("$uv_cmd" --version 2>/dev/null) || installed_version=""
  if [[ "$installed_version" != "uv $UV_VERSION" ]]; then
    _dotfiles_dev_log "Expected uv $UV_VERSION after installation, got: ${installed_version:-no version output}."
    return 1
  fi
  return 0
}

function _dotfiles_dev_select_python {
  local python_dir python_cmd uv_cmd tools_dir
  python_dir="$1"
  tools_dir="$2"
  python_cmd=$(_dotfiles_dev_find_python "$python_dir") || true
  if [[ -n "$python_cmd" ]]; then
    print -r -- "$python_cmd"
    return 0
  fi

  uv_cmd="$tools_dir/uv"
  _dotfiles_dev_log "Installing repository-local Python $PYTHON_VERSION"
  if ! UV_CACHE_DIR="$tools_dir/cache" "$uv_cmd" python install "$PYTHON_VERSION" --install-dir "$python_dir" --no-bin; then
    _dotfiles_dev_log "Could not install Python $PYTHON_VERSION. Check network access and retry."
    return 1
  fi
  python_cmd=$(_dotfiles_dev_find_python "$python_dir") || true
  if [[ -z "$python_cmd" ]]; then
    _dotfiles_dev_log "The Python $PYTHON_VERSION installation did not provide a usable interpreter."
    return 1
  fi
  print -r -- "$python_cmd"
}

function _dotfiles_dev_activate {
  emulate -L zsh
  setopt PIPE_FAIL
  local script_path repo_root tools_dir python_dir venv_dir python_cmd uv_cmd

  script_path=${${(%):-%x}:A}
  repo_root=${script_path:h}
  tools_dir="$repo_root/.devtools"
  python_dir="$tools_dir/python"
  venv_dir="$tools_dir/venv"

  if [[ ! -f "$repo_root/pyproject.toml" || ! -d "$repo_root/dotfiles_dev" ]]; then
    _dotfiles_dev_log "activate.sh must be inside the dotfiles repository (missing pyproject.toml or dotfiles_dev/)."
    return 1
  fi
  if ! _dotfiles_dev_install_uv "$tools_dir"; then
    return 1
  fi
  uv_cmd="$tools_dir/uv"

  python_cmd=$(_dotfiles_dev_find_python "$python_dir") || true
  if [[ -z "$python_cmd" && -x "$venv_dir/bin/python" ]] &&
    "$venv_dir/bin/python" -c 'import sys; assert sys.version_info >= (3, 11)' 2>/dev/null; then
    python_cmd="$venv_dir/bin/python"
  fi
  if [[ -z "$python_cmd" ]]; then
    python_cmd=$(_dotfiles_dev_select_python "$python_dir" "$tools_dir") || return 1
  fi
  print -- "Installing the editable dev entrypoint"
  if ! "$python_cmd" "$repo_root/dotfiles_dev/install_launcher.py" \
    --python "$python_cmd" --venv "$venv_dir" --source "$repo_root" --editable; then
    _dotfiles_dev_log "Could not prepare the launcher virtual environment. Check package index access and retry."
    return 1
  fi

  export VIRTUAL_ENV="$venv_dir"
  path=("$venv_dir/bin" ${path:#"$venv_dir/bin"})
  rehash
  print -- "Activated. 'dev' is available; try: dev env"
}

# Test the result so ERR_EXIT cannot interrupt cleanup. The caller must also
# handle a nonzero source status when running with ERR_EXIT / set -e.
if _dotfiles_dev_activate; then
  unfunction _dotfiles_dev_activate _dotfiles_dev_find_python _dotfiles_dev_install_uv _dotfiles_dev_select_python _dotfiles_dev_log
else
  unfunction _dotfiles_dev_activate _dotfiles_dev_find_python _dotfiles_dev_install_uv _dotfiles_dev_select_python _dotfiles_dev_log
  return 1
fi
