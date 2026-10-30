import os
from pathlib import Path
import shlex
import shutil
import subprocess

import pytest


ROOT = Path(__file__).resolve().parents[1]


def executable(path, body):
    path.write_text("#!/bin/sh\nset -eu\n" + body)
    path.chmod(0o755)


@pytest.fixture
def installation(tmp_path):
    root = tmp_path / "installation with spaces"
    root.mkdir()
    system_nix = root / "system-profile/bin/nix"
    # Prevent the machine running pytest from supplying Nix behind the mocks.
    script = (ROOT / "install.sh").read_text().replace(
        "/nix/var/nix/profiles/default/bin/nix", shlex.quote(str(system_nix))
    )
    (root / "install.sh").write_text(script)
    for name in ("flake.nix", "pyproject.toml"):
        shutil.copyfile(ROOT / name, root / name)
    # The mock checks that the lock is staged unchanged; real lock evaluation
    # belongs to the Nix build checks, not these installer process tests.
    (root / "flake.lock").write_text('{"locked-input-marker": true}\n')
    shutil.copytree(ROOT / "dotfiles_dev", root / "dotfiles_dev")
    bin_dir = root / "test-bin"
    bin_dir.mkdir()
    for name in ("dirname", "mkdir", "sh", "cp", "mktemp", "rm", "cat", "chmod", "mv"):
        (bin_dir / name).symlink_to(shutil.which(name))
    executable(bin_dir / "id", "printf '1000\\n'\n")
    executable(bin_dir / "uname", "printf 'Linux\\n'\n")
    home = root / "home"
    home.mkdir()
    temp = root / "tmp"
    temp.mkdir()
    environment = {
        **os.environ,
        "PATH": str(bin_dir),
        "HOME": str(home),
        "TMPDIR": str(temp),
        "INSTALL_ROOT": str(root),
        "NIX_LOG": str(root / "nix.log"),
        "NIX_ENV_LOG": str(root / "nix-env.log"),
        "SYSTEM_NIX": str(system_nix),
    }
    for name in ("NIX_CONFIG", "NIX_REMOTE", "NIX_EXIT"):
        environment.pop(name, None)
    return root, bin_dir, environment


def fake_nix(path):
    path.parent.mkdir(parents=True, exist_ok=True)
    executable(
        path,
        'printf "%s\\n" "$@" > "$NIX_LOG"\n'
        'printf "%s\\n" "${VIRTUAL_ENV:-}" "${NIX_CONFIG:-}" '
        '"${NIX_REMOTE:-}" > "$NIX_ENV_LOG"\n'
        'previous=\n'
        'for argument do\n'
        '    if [ "$previous" = --out-link ]; then output=$argument; fi\n'
        '    previous=$argument\n'
        'done\n'
        'package=${argument##*#}\n'
        'staged=${argument#path:}\n'
        'staged=${staged%#*}\n'
        '[ -f "$staged/flake.nix" ]\n'
        '[ "$(cat "$staged/flake.lock")" = \'{"locked-input-marker": true}\' ]\n'
        '[ -f "$staged/pyproject.toml" ]\n'
        '[ -f "$staged/dotfiles_dev/cli.py" ]\n'
        '[ ! -L "$staged/dotfiles_dev" ]\n'
        '[ ! -e "$staged/.git" ]\n'
        '[ ! -e "$staged/.devtools" ]\n'
        '[ ! -e "$staged/project-venv" ]\n'
        'printf "%s\\n" "$staged" > "$INSTALL_ROOT/staged-path"\n'
        '[ "${NIX_EXIT:-0}" -eq 0 ] || exit "$NIX_EXIT"\n'
        'if [ "$package" = editable ]; then\n'
        '    [ "$output" = "$INSTALL_ROOT/.devtools/runtime" ]\n'
        '    mkdir -p "$output/bin"\n'
        '    cat > "$output/bin/dev" <<\'EOF\'\n'
        '#!/bin/sh\n'
        'printf "%s\\n" "$DEVCHAIN_SOURCE" "$@"\n'
        'EOF\n'
        '    chmod +x "$output/bin/dev"\n'
        'fi\n',
    )


def bootstrap(installation, *, destination="profile", exit_code=0):
    root, bin_dir, env = installation
    fake_nix(bin_dir / "downloaded-nix")
    env["MOCK_NIX"] = str(bin_dir / "downloaded-nix")
    env["BOOTSTRAP_DESTINATION"] = destination
    env["BOOTSTRAP_EXIT"] = str(exit_code)
    installer = root / "nix-installer.sh"
    installer.write_text(
        'printf "%s\\n" "$@" > "$INSTALL_ROOT/bootstrap.log"\n'
        '[ "$BOOTSTRAP_EXIT" -eq 0 ] || exit "$BOOTSTRAP_EXIT"\n'
        'case "$BOOTSTRAP_DESTINATION" in\n'
        '  profile) destination="$HOME/.nix-profile/bin/nix" ;;\n'
        '  system) destination="$SYSTEM_NIX" ;;\n'
        '  missing) exit 0 ;;\n'
        'esac\n'
        'mkdir -p "$(dirname "$destination")"\n'
        'cp "$MOCK_NIX" "$destination"\n'
    )
    env["MOCK_INSTALLER"] = str(installer)
    executable(
        bin_dir / "curl",
        'printf "%s\\n" "$@" > "$INSTALL_ROOT/curl.log"\n'
        'cat "$MOCK_INSTALLER"\n',
    )


def as_root(installation):
    root, bin_dir, _ = installation
    executable(bin_dir / "id", "printf '0\\n'\n")
    # Root destinations are inspected, never created on the pytest host.
    (bin_dir / "mkdir").unlink()
    executable(
        bin_dir / "mkdir",
        'case "$*" in\n'
        '  "-p /nix"|"-p /opt/devchain /usr/local/bin")\n'
        '    printf "%s\\n" "$@" >> "$INSTALL_ROOT/mkdir.log" ;;\n'
        '  *)\n'
        '    [ "$1" = -p ] || exit 90\n'
        '    shift\n'
        '    for argument do\n'
        '      case "$argument" in "$INSTALL_ROOT"/*) ;; *) exit 90 ;; esac\n'
        '    done\n'
        '    exec /bin/mkdir -p "$@" ;;\n'
        'esac\n',
    )
    executable(
        bin_dir / "ln",
        'printf "%s\\n" "$@" > "$INSTALL_ROOT/ln.log"\n',
    )
    return root


def run(installation, command="sh ./install.sh"):
    root, _, environment = installation
    return subprocess.run(
        ["/bin/sh", "-c", command], cwd=root, env=environment,
        text=True, capture_output=True, timeout=10,
    )


def assert_locked_build(root, output, package):
    arguments = (root / "nix.log").read_text().splitlines()
    assert arguments[:-1] == [
        "--extra-experimental-features", "nix-command flakes", "build",
        "--no-update-lock-file", "--out-link", str(output),
    ]
    assert arguments[-1].startswith(f"path:{root / 'tmp'}/")
    assert arguments[-1].endswith(f"#{package}")
    staged = Path((root / "staged-path").read_text().strip())
    assert not staged.exists(), "staged sources should be removed after the build"


def test_existing_nix_installs_without_system_python_and_stages_only_inputs(installation):
    root, bin_dir, env = installation
    fake_nix(bin_dir / "nix")
    (root / ".git").mkdir()
    (root / ".devtools").mkdir()
    (root / "project-venv").mkdir()
    env["VIRTUAL_ENV"] = str(root / "project-venv")
    result = run(installation)
    assert result.returncode == 0, result.stderr
    assert shutil.which("python", path=env["PATH"]) is None
    assert shutil.which("python3", path=env["PATH"]) is None
    assert_locked_build(root, root / ".devtools/runtime", "editable")
    launcher = run(installation, '.devtools/bin/dev "argument with spaces" --help')
    assert launcher.returncode == 0, launcher.stderr
    assert launcher.stdout.splitlines() == [str(root), "argument with spaces", "--help"]


@pytest.mark.parametrize("location", ["profile", "system"])
def test_existing_nix_outside_path_is_reused(installation, location):
    root, _, env = installation
    nix = (Path(env["HOME"]) / ".nix-profile/bin/nix"
           if location == "profile" else Path(env["SYSTEM_NIX"]))
    fake_nix(nix)
    result = run(installation)
    assert result.returncode == 0, result.stderr
    assert_locked_build(root, root / ".devtools/runtime", "editable")


def test_host_bootstrap_uses_daemon_and_reinstall_preserves_caller_environment(installation):
    root, bin_dir, env = installation
    bootstrap(installation)
    env.update({
        "VIRTUAL_ENV": str(root / "project-venv"),
        "NIX_CONFIG": "max-jobs = 2",
        "NIX_REMOTE": "daemon",
    })
    command = (
        'sh ./install.sh && printf "%s\\n" "$VIRTUAL_ENV" "$NIX_CONFIG" '
        '"$NIX_REMOTE" > "$INSTALL_ROOT/caller-env.log"'
    )
    result = run(installation, command)
    assert result.returncode == 0, result.stderr
    assert (root / "bootstrap.log").read_text().splitlines() == [
        "--daemon", "--no-channel-add", "--yes",
    ]
    download = (root / "curl.log").read_text().splitlines()
    assert download == [
        "--fail", "--silent", "--show-error", "--location",
        "https://releases.nixos.org/nix/nix-2.28.5/install",
    ]
    expected_env = [env["VIRTUAL_ENV"], env["NIX_CONFIG"], env["NIX_REMOTE"]]
    assert (root / "nix-env.log").read_text().splitlines() == expected_env
    assert (root / "caller-env.log").read_text().splitlines() == expected_env
    executable(bin_dir / "curl", "exit 22\n")
    result = run(installation, command)
    assert result.returncode == 0, result.stderr
    assert (root / "nix-env.log").read_text().splitlines() == expected_env
    assert (root / "caller-env.log").read_text().splitlines() == expected_env


def test_root_feature_bootstrap_builds_packaged_cli_without_git(installation):
    root, _, env = installation
    as_root(installation)
    bootstrap(installation, destination="system")
    env["NIX_CONFIG"] = "max-jobs = 2"
    env["NIX_REMOTE"] = "daemon"
    assert not (root / ".git").exists()
    assert not (root / ".devtools").exists()
    # Local Feature packaging uses symlinked inputs; the build must copy them.
    linked_source = root / "feature-package"
    (root / "dotfiles_dev").rename(linked_source)
    (root / "dotfiles_dev").symlink_to(linked_source, target_is_directory=True)
    result = run(
        installation,
        'sh ./install.sh && printf "%s\\n" "$NIX_CONFIG" "$NIX_REMOTE" '
        '> "$INSTALL_ROOT/caller-env.log"',
    )
    assert result.returncode == 0, result.stderr
    assert (root / "bootstrap.log").read_text().splitlines() == [
        "--no-daemon", "--no-channel-add", "--no-modify-profile", "--yes",
    ]
    assert_locked_build(root, "/opt/devchain/runtime", "default")
    assert (root / "mkdir.log").read_text().splitlines() == [
        "-p", "/nix", "-p", "/opt/devchain", "/usr/local/bin",
    ]
    assert (root / "ln.log").read_text().splitlines() == [
        "-sfn", "/opt/devchain/runtime/bin/dev", "/usr/local/bin/dev",
    ]
    assert (root / "nix-env.log").read_text().splitlines()[-4:] == [
        "max-jobs = 2", "build-users-group =", "sandbox = false", "local",
    ]
    assert (root / "caller-env.log").read_text().splitlines() == [
        "max-jobs = 2", "daemon",
    ]


def test_migration_replaces_old_launcher_symlink_without_modifying_its_target(installation):
    root, bin_dir, _ = installation
    fake_nix(bin_dir / "nix")
    tools_bin = root / ".devtools/bin"
    tools_bin.mkdir(parents=True)
    old_target = root / "old-uv-dev"
    old_target.write_text("old uv launcher\n")
    (tools_bin / "dev").symlink_to(old_target)
    result = run(installation)
    assert result.returncode == 0, result.stderr
    assert old_target.read_text() == "old uv launcher\n"
    assert not (tools_bin / "dev").is_symlink()
    assert os.access(tools_bin / "dev", os.X_OK)


def test_download_failure_stops_installation(installation):
    root, bin_dir, _ = installation
    executable(bin_dir / "curl", "exit 22\n")
    result = run(installation)
    assert result.returncode == 22
    assert not (root / "nix.log").exists()
    assert not (root / ".devtools/bin/dev").exists()
    assert "Installed dev" not in result.stdout


@pytest.mark.parametrize("exit_code,destination", [(7, "profile"), (0, "missing")])
def test_bootstrap_failure_does_not_claim_success(installation, exit_code, destination):
    root, _, _ = installation
    bootstrap(installation, exit_code=exit_code, destination=destination)
    result = run(installation)
    assert result.returncode == (exit_code or 1)
    assert not (root / "nix.log").exists()
    assert not (root / ".devtools/bin/dev").exists()
    assert "Installed dev" not in result.stdout


def test_build_failure_cleans_up_and_does_not_install_launcher(installation):
    root, bin_dir, env = installation
    fake_nix(bin_dir / "nix")
    env["NIX_EXIT"] = "9"
    result = run(installation)
    assert result.returncode == 9
    assert "Installed dev" not in result.stdout
    assert not (root / ".devtools/bin/dev").exists()
    assert_locked_build(root, root / ".devtools/runtime", "editable")
