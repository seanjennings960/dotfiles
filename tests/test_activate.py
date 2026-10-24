import os
from pathlib import Path
import shutil
import subprocess
import sys

import pytest


ACTIVATE = Path(__file__).resolve().parents[1] / "activate.sh"
ZSH = shutil.which("zsh")
BASH = shutil.which("bash")


@pytest.fixture
def activation(tmp_path):
    root = tmp_path / "activation test"
    root.mkdir()
    shutil.copyfile(ACTIVATE, root / "activate.sh")
    (root / "pyproject.toml").touch()
    (root / "dotfiles_dev").mkdir()
    shutil.copyfile(ACTIVATE.parent / "dotfiles_dev" / "install_launcher.py",
                    root / "dotfiles_dev" / "install_launcher.py")
    bin_dir = root / "bin"
    bin_dir.mkdir()
    return root, bin_dir, {
        **os.environ, "PATH": str(bin_dir), "REAL_PYTHON": sys.executable,
    }


def run_shell(activation, shell, command):
    root, _, env = activation
    return subprocess.run(
        [shell, "-c", command], cwd=root, env=env,
        text=True, capture_output=True, timeout=10,
    )


def executable(path, body):
    path.write_text("#!/bin/sh\n" + body)
    path.chmod(0o755)


def fake_python(path):
    executable(
        path,
        'if [ "$1" = -m ] && [ "$2" = venv ] && [ "$3" != --help ]; then\n'
        '  /bin/mkdir -p "$3/bin"\n'
        '  /bin/cp "$0" "$3/bin/python"\n'
        '  /bin/cp "$0" "$3/bin/pip"\n'
        'elif [ "$1" = -m ] && [ "$2" = pip ] && [ "${MOCK_UV_FAIL_PIP:-0}" = 1 ]; then\n'
        '  exit 1\n'
        'elif [ "${1##*.}" = py ]; then\n'
        '  exec "$REAL_PYTHON" "$@"\n'
        'fi\nexit 0\n',
    )


def fake_uv(activation, path):
    _, bin_dir, env = activation
    fake_python(bin_dir / "downloaded-python")
    env["MOCK_PYTHON"] = str(bin_dir / "downloaded-python")
    executable(
        path,
        'if [ "$1" = --version ]; then\n'
        '  printf "uv 0.13.1\\n"\n'
        'elif [ "$1" = python ] && [ "$2" = install ]; then\n'
        '  python_bin="$5/cpython-3.11.17-test/bin"\n'
        '  /bin/mkdir -p "$python_bin"\n'
        '  /bin/cp "$MOCK_PYTHON" "$python_bin/python3.11"\n'
        'fi\n',
    )


def install_mock_uv(activation):
    root, _, _ = activation
    uv = root / ".devtools" / "uv"
    uv.parent.mkdir(parents=True, exist_ok=True)
    executable(
        uv,
        'if [ "$1" = --version ]; then printf "uv 0.13.1\\n"; fi\n',
    )

@pytest.mark.skipif(not BASH, reason="Bash is required")
def test_bash_rejection_returns_without_exiting_shell(activation):
    result = run_shell(
        activation,
        BASH, 'source ./activate.sh; status=$?; printf "survived:%s\\n" "$status"',
    )
    assert result.returncode == 0, result.stderr
    assert "survived:1" in result.stdout
    assert "requires Zsh" in result.stderr

@pytest.mark.skipif(not ZSH, reason="Zsh is required")
def test_missing_python_returns_failure_and_cleans_up(activation):
    result = run_shell(
        activation,
        ZSH, 'source ./activate.sh; result=$?; '
        'print "survived:$result function:${+functions[_dotfiles_dev_activate]}"',
    )
    assert result.returncode == 0, result.stderr
    assert "survived:1 function:0" in result.stdout
    assert "Bootstrapping the development tools requires curl and sh" in result.stderr

@pytest.mark.skipif(not ZSH, reason="Zsh is required")
def test_err_exit_with_failure_handler_keeps_shell_open(activation):
    result = run_shell(
        activation,
        ZSH, 'setopt ERR_EXIT; source ./activate.sh || print "failed:$?"; '
        'print "survived function:${+functions[_dotfiles_dev_activate]}"',
    )
    assert result.returncode == 0, result.stderr
    assert "failed:1" in result.stdout
    assert "survived function:0" in result.stdout

@pytest.mark.skipif(not ZSH, reason="Zsh is required")
def test_execution_requires_sourcing(activation):
    root, _, env = activation
    result = subprocess.run(
        [ZSH, str(root / "activate.sh")], env=env,
        text=True, capture_output=True, timeout=10,
    )
    assert result.returncode == 1
    assert "Source this script from Zsh" in result.stderr

@pytest.mark.skipif(not ZSH, reason="Zsh is required")
def test_install_failure_preserves_environment(activation):
    root, bin_dir, _ = activation
    install_mock_uv(activation)
    activation[2]["MOCK_UV_FAIL_PIP"] = "1"
    executable(bin_dir / "python3", "exit 0\n")
    venv_bin = root / ".devtools" / "venv" / "bin"
    venv_bin.mkdir(parents=True)
    fake_python(venv_bin / "python")
    executable(venv_bin / "pip", "exit 0\n")
    result = run_shell(
        activation,
        ZSH, 'setopt ERR_EXIT; export VIRTUAL_ENV=original; original_path=$PATH; '
        'source ./activate.sh || print "failed:$?"; '
        '[[ $PATH == $original_path ]] || exit 99; '
        'print "venv:$VIRTUAL_ENV function:${+functions[_dotfiles_dev_activate]}"',
    )
    assert result.returncode == 0, result.stderr
    assert "failed:1" in result.stdout
    assert "venv:original function:0" in result.stdout
    assert "Could not prepare the launcher virtual environment" in result.stderr

@pytest.mark.skipif(not ZSH, reason="Zsh is required")
def test_local_python_creates_venv_when_system_python_is_too_old(activation):
    root, bin_dir, _ = activation
    install_mock_uv(activation)
    executable(bin_dir / "python", "exit 1\n")
    executable(bin_dir / "python3", "exit 1\n")
    python_bin = root / ".devtools" / "python" / "cpython-3.11.17-test" / "bin"
    python_bin.mkdir(parents=True)
    fake_python(python_bin / "python3.11")
    result = run_shell(
        activation,
        ZSH, 'source ./activate.sh || exit 99; print "venv:$VIRTUAL_ENV"',
    )
    assert result.returncode == 0, result.stderr
    assert (root / ".devtools" / "venv" / "bin" / "python").is_file()
    assert f"venv:{root}/.devtools/venv" in result.stdout

@pytest.mark.skipif(not ZSH, reason="Zsh is required")
def test_existing_old_venv_is_backed_up_and_replaced(activation):
    root, bin_dir, _ = activation
    install_mock_uv(activation)
    venv_bin = root / ".devtools" / "venv" / "bin"
    venv_bin.mkdir(parents=True)
    executable(venv_bin / "python", 'printf "Python 3.9.6\\n"\nexit 1\n')
    executable(venv_bin / "pip", "exit 0\n")
    python_bin = root / ".devtools" / "python" / "cpython-3.11.17-test" / "bin"
    python_bin.mkdir(parents=True)
    fake_python(python_bin / "python3.11")
    for name in ("mktemp", "mv"):
        (bin_dir / name).symlink_to(shutil.which(name))
    result = run_shell(activation, ZSH, 'source ./activate.sh || exit 99')
    assert result.returncode == 0, result.stderr
    backups = list((root / ".devtools").glob("venv-backup.*/venv/bin/python"))
    assert len(backups) == 1
    assert "Python 3.9.6" in backups[0].read_text()
    assert "Preserved the old virtual environment" in result.stderr
    assert "Python 3.9.6" not in (venv_bin / "python").read_text()

@pytest.mark.skipif(not ZSH, reason="Zsh is required")
def test_bootstrap_downloads_python_with_cached_uv(activation):
    root, _, _ = activation
    tools = root / ".devtools"
    tools.mkdir()
    fake_uv(activation, tools / "uv")
    result = run_shell(activation, ZSH, 'source ./activate.sh || exit 99')
    assert result.returncode == 0, result.stderr
    assert (root / ".devtools" / "venv" / "bin" / "python").exists()
    assert "Installing repository-local Python 3.11.17" in result.stderr

@pytest.mark.skipif(not ZSH, reason="Zsh is required")
def test_fresh_bootstrap_installs_uv_and_python(activation):
    root, bin_dir, env = activation
    fake_uv(activation, bin_dir / "mock-uv")
    env["MOCK_UV"] = str(bin_dir / "mock-uv")
    installer = bin_dir / "mock-installer"
    executable(
        installer,
        '[ "$UV_VERSION" = 0.13.1 ] || exit 1\n'
        '[ "$UV_NO_MODIFY_PATH" = 1 ] || exit 1\n'
        '[ "$UV_NO_INSTALLER_METADATA" = 1 ] || exit 1\n'
        '/bin/cp "$MOCK_UV" "$UV_INSTALL_DIR/uv"\n',
    )
    env["MOCK_UV_INSTALLER"] = str(installer)
    executable(bin_dir / "curl", '/bin/cat "$MOCK_UV_INSTALLER"\n')
    for name in ("sh", "mkdir"):
        (bin_dir / name).symlink_to(shutil.which(name))
    result = run_shell(activation, ZSH, 'setopt ERR_EXIT; source ./activate.sh || exit 99')
    assert result.returncode == 0, result.stderr
    assert (root / ".devtools" / "uv").exists()
    assert (root / ".devtools" / "venv" / "bin" / "python").exists()

@pytest.mark.skipif(not ZSH, reason="Zsh is required")
def test_failed_download_preserves_environment(activation):
    root, bin_dir, _ = activation
    executable(bin_dir / "curl", "exit 22\n")
    for name in ("sh", "mkdir"):
        (bin_dir / name).symlink_to(shutil.which(name))
    result = run_shell(
        activation,
        ZSH, 'setopt ERR_EXIT; export VIRTUAL_ENV=original; original_path=$PATH; '
        'source ./activate.sh || print "failed:$?"; '
        '[[ $PATH == $original_path ]] || exit 99; print "venv:$VIRTUAL_ENV"',
    )
    assert result.returncode == 0, result.stderr
    assert "failed:1" in result.stdout
    assert "venv:original" in result.stdout
    assert "Could not install uv" in result.stderr
    assert not (root / ".devtools" / "venv").exists()

@pytest.mark.skipif(not ZSH, reason="Zsh is required")
def test_existing_venv_activates_without_system_python(activation):
    root, _, _ = activation
    install_mock_uv(activation)
    venv_bin = root / ".devtools" / "venv" / "bin"
    venv_bin.mkdir(parents=True)
    executable(venv_bin / "python", "exit 0\n")
    executable(venv_bin / "pip", "exit 0\n")
    result = run_shell(
        activation,
        ZSH, 'setopt ERR_EXIT; source ./activate.sh || exit 99; '
        'print -r -- "venv:$VIRTUAL_ENV" "first:$path[1]"; '
        'source ./activate.sh || exit 99; '
        'print "path_entries:${#path}"',
    )
    assert result.returncode == 0, result.stderr
    assert f"venv:{root}/.devtools/venv" in result.stdout
    assert f"first:{venv_bin}" in result.stdout
    assert "path_entries:2" in result.stdout
