#!/usr/bin/env zsh

# The repository's `dev` command can be tested from a plain Zsh shell without
# installing it globally. From Zsh, run this from the repository:
#
# ```zsh
# source ./activate.sh || print -u2 'Activation failed'
# dev env
# ```
#
# Source the script (rather than running it) so it can add the repository's
# `.dev-venv/bin` directory to the current shell's `PATH`. The script creates the
# virtual environment if needed and installs the launcher in editable mode.
# It reuses the Python inside an existing `.dev-venv` if it is 3.11 or newer.
# Otherwise it uses a local Python 3.11 in `.dev-python/`, downloading it when
# needed. No preinstalled Python or uv is required.
# The failure handler keeps Zsh open if `ERR_EXIT` is enabled.
# The script requires Zsh. Sourcing it from Bash reports an error and returns.
#
# ### Repository-local Python 3.11
#
# `activate.sh` handles the entire installation. On a fresh checkout it uses
# `curl` and `sh` to install [uv](https://docs.astral.sh/uv/) in `.dev-tools/`,
# downloads Python 3.11 into `.dev-python/`, and creates `.dev-venv/`. Internet
# access is required for these downloads and package installation. The bootstrap
# uses standard shell utilities and does not modify shell startup files.
#
# An existing venv with an older Python is preserved under
# `.dev-venv-backup.<unique suffix>/venv` before the script creates its replacement.
# Subsequent activations reuse the installed Python and venv. The generated
# directories are ignored by Git. Keep `.dev-python/` in place because the venv
# depends on that interpreter.

# Source this file from Zsh to activate the repository's host-side dev CLI.
if [ -z "${ZSH_VERSION:-}" ]; then
  printf '%s\n' 'activate.sh requires Zsh. Run: zsh, then source ./activate.sh' >&2
  return 1 2>/dev/null || exit 1
fi

if [[ ${ZSH_EVAL_CONTEXT:-} != *:file* ]]; then
  print -u2 -- "Source this script from Zsh: source ${0:A:h}/activate.sh"
  exit 1
fi

function _dotfiles_dev_activate {
  emulate -L zsh
  setopt PIPE_FAIL
  local script_path repo_root python_cmd tools_dir python_dir venv_dir candidate uv_cmd backup_dir
  local rebuild_venv=0
  local -a python_candidates

  script_path=${${(%):-%x}:A}
  repo_root=${script_path:h}
  tools_dir="$repo_root/.devtools"
  python_dir="$tools_dir/python"
  venv_dir="$tools_dir/venv"

  if [[ ! -f "$repo_root/pyproject.toml" || ! -d "$repo_root/dotfiles_dev" ]]; then
    print -u2 -- "activate.sh must be inside the dotfiles repository (missing pyproject.toml or dotfiles_dev/)."
    return 1
  fi

  if [[ -L "$venv_dir" ]]; then
    print -u2 -- "Refusing to use a symlink at $venv_dir; remove or rename it and retry."
    return 1
  fi

  if [[ -d "$venv_dir" ]]; then
    if [[ ! -x "$venv_dir/bin/python" || ! -x "$venv_dir/bin/pip" ]]; then
      print -u2 -- "$venv_dir exists but is not a usable Python virtual environment. Move it aside and retry."
      return 1
    fi
    if "$venv_dir/bin/python" -c 'import sys; assert sys.version_info >= (3, 11)' 2>/dev/null; then
      python_cmd="$venv_dir/bin/python"
    else
      rebuild_venv=1
    fi
  fi

  if [[ -z "$python_cmd" ]]; then
    python_candidates=("$python_dir"/cpython-3.11*/bin/python3.11(N))
    for candidate in "${python_candidates[@]}"; do
      if "$candidate" -c 'import sys; assert sys.version_info >= (3, 11)' 2>/dev/null; then
        python_cmd="$candidate"
        break
      fi
    done
    if [[ -z "$python_cmd" ]]; then
      uv_cmd="$tools_dir/uv"
      if [[ ! -x "$uv_cmd" ]]; then
        if ! command -v curl >/dev/null || ! command -v sh >/dev/null; then
          print -u2 -- "Bootstrapping Python 3.11 requires curl and sh on PATH."
          return 1
        fi
        print -- "Installing repository-local uv"
        if ! command mkdir -p "$tools_dir"; then
          print -u2 -- "Could not create .devtools."
          return 1
        fi
        if ! command curl --fail --silent --show-error --location https://astral.sh/uv/install.sh |
          UV_INSTALL_DIR="$tools_dir" UV_NO_MODIFY_PATH=1 UV_NO_INSTALLER_METADATA=1 command sh; then
          print -u2 -- "Could not install uv. Check network access and retry."
          return 1
        fi
      fi
      print -- "Installing repository-local Python 3.11"
      if ! UV_CACHE_DIR="$tools_dir/cache" "$uv_cmd" python install 3.11 --install-dir "$python_dir" --no-bin; then
        print -u2 -- "Could not install Python 3.11. Check network access and retry."
        return 1
      fi
      python_candidates=("$python_dir"/cpython-3.11*/bin/python3.11(N))
      for candidate in "${python_candidates[@]}"; do
        if "$candidate" -c 'import sys; assert sys.version_info >= (3, 11)' 2>/dev/null; then
          python_cmd="$candidate"
          break
        fi
      done
      if [[ -z "$python_cmd" ]]; then
        print -u2 -- "The Python 3.11 installation did not provide a usable interpreter."
        return 1
      fi
    fi
  fi

  if ! "$python_cmd" -m pip --version >/dev/null 2>&1; then
    print -u2 -- "The selected Python does not have a working pip module."
    return 1
  fi
  if [[ ! -d "$venv_dir" || "$rebuild_venv" == 1 ]]; then
    if ! "$python_cmd" -m venv --help >/dev/null 2>&1; then
      print -u2 -- "The selected Python does not provide the venv module."
      return 1
    fi
    if [[ "$rebuild_venv" == 1 ]]; then
      backup_dir=$(command mktemp -d "$tools_dir/venv-backup.XXXXXXXX") || {
        print -u2 -- "Could not create a backup directory for the old virtual environment."
        return 1
      }
      if ! command mv "$venv_dir" "$backup_dir/venv"; then
        print -u2 -- "Could not preserve the old virtual environment at $backup_dir/venv."
        return 1
      fi
      print -- "Preserved the old virtual environment at $backup_dir/venv"
    fi
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

# Test the result so ERR_EXIT cannot interrupt cleanup. The caller must also
# handle a nonzero source status when running with ERR_EXIT / set -e.
if _dotfiles_dev_activate; then
  unfunction _dotfiles_dev_activate
else
  unfunction _dotfiles_dev_activate
  return 1
fi
