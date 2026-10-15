import os
from pathlib import Path
import shutil
import subprocess

import pytest


ROOT = Path(__file__).resolve().parents[1]


def executable(path, body):
    path.write_text("#!/bin/sh\n" + body)
    path.chmod(0o755)


@pytest.fixture
def installation(tmp_path):
    root = tmp_path / "installation with spaces"
    root.mkdir()
    shutil.copyfile(ROOT / "install.sh", root / "install.sh")
    bin_dir = root / "bin"
    bin_dir.mkdir()
    # Provisioning must work without system Python, pip, or uv.
    for name in ("dirname", "mkdir", "sh"):
        (bin_dir / name).symlink_to(shutil.which(name))
    executable(bin_dir / "id", "printf '1000\\n'\n")
    environment = {
        **os.environ, "PATH": str(bin_dir), "UV_LOG": str(root / "uv.log"),
    }
    return root, bin_dir, environment


def fake_uv(path):
    executable(
        path,
        'printf "%s\\n" "$UV_TOOL_DIR" "$UV_PYTHON_INSTALL_DIR" '
        '"$UV_TOOL_BIN_DIR" "$UV_CACHE_DIR" "$@" > "$UV_LOG"\n'
        'exit "${UV_EXIT:-0}"\n',
    )


def run(installation, command='sh ./install.sh'):
    root, _, environment = installation
    return subprocess.run(
        ["/bin/sh", "-c", command], cwd=root, env=environment,
        text=True, capture_output=True, timeout=10,
    )


def test_install_uses_local_uv_without_system_python(installation):
    root, _, env = installation
    tools = root / ".devtools"
    tools.mkdir()
    fake_uv(tools / "uv")
    env["VIRTUAL_ENV"] = str(root / "project-venv")
    result = run(installation)
    assert result.returncode == 0, result.stderr
    assert (root / "uv.log").read_text().splitlines() == [
        str(tools / "tools"), str(tools / "python"), str(tools / "bin"),
        str(tools / "cache"), "tool", "install", "--python", "3.11.17",
        "--managed-python", "--force", "--editable", str(root),
    ]


def test_bootstrap_installs_uv_and_reuses_it(installation):
    root, bin_dir, env = installation
    fake_uv(bin_dir / "downloaded-uv")
    env["MOCK_UV"] = str(bin_dir / "downloaded-uv")
    installer = root / "uv-installer.sh"
    installer.write_text(
        '[ "$UV_NO_MODIFY_PATH" = 1 ] || exit 1\n'
        '[ "$UV_NO_INSTALLER_METADATA" = 1 ] || exit 1\n'
        '/bin/cp "$MOCK_UV" "$UV_INSTALL_DIR/uv"\n'
    )
    env["MOCK_INSTALLER"] = str(installer)
    executable(bin_dir / "curl", '/bin/cat "$MOCK_INSTALLER"\n')
    result = run(installation)
    assert result.returncode == 0, result.stderr
    assert (root / ".devtools/uv").is_file()
    executable(bin_dir / "curl", "exit 22\n")
    result = run(installation)
    assert result.returncode == 0, result.stderr


def test_download_failure_stops_installation(installation):
    root, bin_dir, _ = installation
    executable(bin_dir / "curl", "exit 22\n")
    result = run(installation)
    assert result.returncode == 22
    assert not (root / "uv.log").exists()


def test_install_failure_is_reported(installation):
    root, _, env = installation
    tools = root / ".devtools"
    tools.mkdir()
    fake_uv(tools / "uv")
    env["UV_EXIT"] = "1"
    result = run(installation)
    assert result.returncode == 1
    assert "Installed dev" not in result.stdout
