#!/usr/bin/env zsh

# Source this file from Zsh to activate the repository's host-side dev CLI.
if [[ ${ZSH_EVAL_CONTEXT:-} != *:file* ]]; then
  print -u2 -- "Source this script from Zsh: source ${0:A:h}/activate.sh"
  exit 1
fi

function _dotfiles_dev_activate {
  emulate -L zsh
  local script_path repo_root python_cmd venv_dir

  script_path=${${(%):-%x}:A}
  repo_root=${script_path:h}
  venv_dir="$repo_root/.dev-venv"

  if [[ ! -f "$repo_root/pyproject.toml" || ! -d "$repo_root/dotfiles_dev" ]]; then
    print -u2 -- "activate.sh must be inside the dotfiles repository (missing pyproject.toml or dotfiles_dev/)."
    return 1
  fi

  python_cmd=$(command -v python) || {
    print -u2 -- "Required command 'python' was not found. Install Python 3.11 or newer and retry."
    return 1
  }
  command -v pip >/dev/null || {
    print -u2 -- "Required command 'pip' was not found. Install pip for Python and retry."
    return 1
  }

  if ! "$python_cmd" -c 'import sys; assert sys.version_info >= (3, 11), "Python 3.11 or newer is required"' 2>/dev/null; then
    print -u2 -- "Python 3.11 or newer is required (found: $($python_cmd --version 2>&1))."
    return 1
  fi
  if ! "$python_cmd" -m pip --version >/dev/null 2>&1; then
    print -u2 -- "The selected Python does not have a working pip module."
    return 1
  fi
  if ! "$python_cmd" -m venv --help >/dev/null 2>&1; then
    print -u2 -- "The selected Python does not provide the venv module."
    return 1
  fi

  if [[ -L "$venv_dir" ]]; then
    print -u2 -- "Refusing to use a symlink at $venv_dir; remove or rename it and retry."
    return 1
  fi

  if [[ ! -d "$venv_dir" ]]; then
    print -- "Creating repository virtual environment at $venv_dir"
    if ! "$python_cmd" -m venv "$venv_dir"; then
      print -u2 -- "Could not create the repository virtual environment."
      return 1
    fi
  fi

  if [[ ! -x "$venv_dir/bin/python" || ! -x "$venv_dir/bin/pip" ]]; then
    print -u2 -- "$venv_dir exists but is not a usable Python virtual environment. Move it aside and retry."
    return 1
  fi

  print -- "Installing the editable dev entrypoint"
  if ! "$venv_dir/bin/python" -m pip install --editable "$repo_root"; then
    print -u2 -- "Could not install the dev entrypoint. Check package index access and retry."
    return 1
  fi

  export VIRTUAL_ENV="$venv_dir"
  path=("$venv_dir/bin" ${path:#"$venv_dir/bin"})
  rehash
  print -- "Activated. 'dev' is available; try: dev env"
}

_dotfiles_dev_activate
unfunction _dotfiles_dev_activate
