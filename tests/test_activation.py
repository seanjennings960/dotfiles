"""Exercise the real activation entry points in isolated, non-root homes."""

import json
import os
import shutil
from pathlib import Path

import pytest


def activate(run, repo_root, **kwargs):
    return run([repo_root / "install.sh"], **kwargs)


def snapshot(directory):
    return {str(p.relative_to(directory)): (p.read_bytes(), p.stat().st_mode)
            for p in directory.rglob("*") if p.is_file()}


def test_clean_nonroot_home_and_repeat(run, repo_root, home, env):
    assert os.getuid() != 0
    before = snapshot(repo_root / "opencode")
    nvim_before = snapshot(repo_root / "nvim")
    activate(run, repo_root)
    config = Path(env["XDG_CONFIG_HOME"])
    links = {config / "nvim": repo_root / "nvim",
             home / ".tmux.conf": repo_root / "tmux.conf",
             home / "bin/tmux_neww": repo_root / "tmux/tmux_neww.sh"}
    links.update({config / "dotfiles" / name: repo_root / name
                  for name in ("bashrc", "bash_aliases", "zshrc")})
    links.update({config / "opencode" / name: repo_root / "opencode" / name
                  for name in ("opencode.jsonc", "skills")})
    for destination, source in links.items():
        assert destination.is_symlink()
        assert destination.resolve() == source
    assert os.access(home / "bin/tmux_neww", os.X_OK)
    assert not (config / "opencode").is_symlink()
    assert not (config / "dotfiles").is_symlink()
    for name in ("undo", "swap", "backup"):
        path = Path(env["XDG_STATE_HOME"]) / "nvim" / name
        assert path.is_dir() and os.access(path, os.W_OK)
    initial = snapshot(home)
    inodes = {path: path.lstat().st_ino for path in links}
    run([repo_root / "infectdots.sh"])
    assert snapshot(home) == initial
    assert {path: path.lstat().st_ino for path in links} == inodes
    assert snapshot(repo_root / "opencode") == before
    assert snapshot(repo_root / "nvim") == nvim_before


def test_default_xdg_paths_and_unmanaged_trial_hook(run, repo_root, home, env):
    for variable in ("XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME", "XDG_CACHE_HOME"):
        env.pop(variable)
    trial = home / ".config/dotfiles/nvim-local.lua"
    trial.parent.mkdir(parents=True)
    trial.write_text("-- personal trial\n")
    activate(run, repo_root)
    assert (home / ".config/nvim").resolve() == repo_root / "nvim"
    assert (home / ".local/share/opencode").is_dir()
    assert (home / ".local/state/nvim/undo").is_dir()
    assert (home / ".cache/opencode").is_dir()
    assert trial.read_text() == "-- personal trial\n"


def test_deduplicates_managed_blocks_preserving_surrounding_bytes(run, repo_root, home):
    block = (b"# >>> dotfiles managed startup >>>\n# old managed content\n"
             b"# <<< dotfiles managed startup <<<\n")
    path = home / ".bashrc"
    path.write_bytes(b"# before\n" + block + b"# between\n" + block + b"# after")
    activate(run, repo_root)
    assert path.read_bytes().startswith(b"# before\n# between\n# after\n")
    assert path.read_bytes().count(b"# >>> dotfiles managed startup >>>") == 1
    assert b"old managed content" not in path.read_bytes()
    before = path.read_bytes()
    activate(run, repo_root)
    assert path.read_bytes() == before


@pytest.mark.parametrize("content", [b"# >>> dotfiles managed startup >>>\n",
                                     b"# <<< dotfiles managed startup <<<\n"])
def test_malformed_startup_block_preflight(run, repo_root, home, content):
    path = home / ".bashrc"
    path.write_bytes(content)
    assert activate(run, repo_root, check=False).returncode != 0
    assert path.read_bytes() == content
    assert list(home.iterdir()) == [path]


def test_legacy_opencode_directory_link_is_preserved_conflict(run, repo_root, home):
    (home / ".config").mkdir()
    path = home / ".config/opencode"
    path.symlink_to(repo_root / "opencode")
    before = snapshot(repo_root / "opencode")
    assert activate(run, repo_root, check=False).returncode != 0
    assert path.is_symlink() and path.resolve() == repo_root / "opencode"
    assert snapshot(repo_root / "opencode") == before
    assert not (home / "bin").exists()


@pytest.mark.parametrize("login", [".bash_profile", ".bash_login", ".profile"])
def test_preserves_startup_content_and_login_precedence(run, repo_root, home, login):
    names = [".bash_profile", ".bash_login", ".profile"]
    for name in names[names.index(login):] + [".bashrc", ".zshrc"]:
        (home / name).write_bytes(b"# personal \xff\nexport PERSONAL=yes\n")
        (home / name).chmod(0o600)
    activate(run, repo_root)
    for name in (login, ".bashrc", ".zshrc"):
        content = (home / name).read_bytes()
        assert content.startswith(b"# personal \xff\nexport PERSONAL=yes\n")
        assert content.count(b"# >>> dotfiles managed startup >>>") == 1
        assert (home / name).stat().st_mode & 0o777 == 0o600
    for name in names[names.index(login) + 1:]:
        assert (home / name).read_bytes() == b"# personal \xff\nexport PERSONAL=yes\n"
    run(["bash", "-n", home / ".bashrc", home / login])
    run(["zsh", "-n", home / ".zshrc"])


@pytest.mark.parametrize("kind", ["file", "directory", "foreign", "broken"])
@pytest.mark.parametrize("destination", [".tmux.conf", ".config/nvim",
                                        ".config/dotfiles/bashrc",
                                        ".config/opencode/opencode.jsonc"])
def test_conflicts_preserved_before_any_mutation(run, repo_root, home, kind, destination):
    path = home / destination
    path.parent.mkdir(parents=True, exist_ok=True)
    if kind == "file":
        path.write_text("personal")
    elif kind == "directory":
        path.mkdir()
    else:
        target = home / "personal-target"
        if kind == "foreign":
            target.write_text("personal")
        path.symlink_to(target)
    before = snapshot(home)
    link = os.readlink(path) if path.is_symlink() else None
    result = activate(run, repo_root, check=False)
    assert result.returncode != 0
    assert snapshot(home) == before
    assert not (home / ".bashrc").exists()
    assert not (home / "bin").exists()
    if link is not None:
        assert os.readlink(path) == link


def test_correct_relative_and_trailing_slash_links(run, repo_root, home):
    (home / ".config").mkdir()
    (home / ".config/nvim").symlink_to(str(repo_root / "nvim") + "/")
    (home / ".tmux.conf").symlink_to(os.path.relpath(repo_root / "tmux.conf", home))
    inode = (home / ".tmux.conf").lstat().st_ino
    activate(run, repo_root)
    assert (home / ".tmux.conf").lstat().st_ino == inode


@pytest.mark.parametrize("missing", ["nvim", "tmux.conf", "bash_aliases",
                                    "opencode/opencode.jsonc"])
def test_missing_sources_preflight(run, repo_root, home, workspace, missing):
    copy = workspace / "repository"
    shutil.copytree(repo_root, copy, ignore=shutil.ignore_patterns(".git", "__pycache__"))
    source = copy / missing
    if source.is_dir():
        shutil.rmtree(source)
    else:
        source.unlink()
    result = activate(run, copy, check=False)
    assert result.returncode != 0 and "Missing source" in result.stderr
    assert list(home.iterdir()) == []


def test_unwritable_destination_preflight(run, repo_root, home):
    (home / "bin").mkdir(mode=0o500)
    try:
        result = activate(run, repo_root, check=False)
        assert result.returncode != 0
        assert list(home.iterdir()) == [home / "bin"]
    finally:
        (home / "bin").chmod(0o700)


def test_injected_ln_failure_rolls_back(run, repo_root, home, env, workspace):
    tools = workspace / "tools"
    tools.mkdir()
    fake = tools / "ln"
    # Fail after one successful link to exercise rollback, not just preflight.
    fake.write_text('#!/bin/sh\nif [ -L "$HOME/.config/nvim" ]; then exit 42; fi\n'
                    'exec /usr/bin/ln "$@"\n')
    fake.chmod(0o755)
    env["PATH"] = f"{tools}:{env['PATH']}"
    (home / ".bashrc").write_text("# keep me\n")
    before = snapshot(home)
    result = activate(run, repo_root, check=False)
    assert result.returncode != 0
    assert snapshot(home) == before
    assert list(home.iterdir()) == [home / ".bashrc"]


@pytest.mark.parametrize("value", ["", "relative", "/does-not-exist/dotfiles-home"])
def test_invalid_home(run, repo_root, home, env, value):
    env["HOME"] = value
    assert activate(run, repo_root, check=False).returncode != 0
    assert list(home.iterdir()) == []


@pytest.mark.parametrize("variable", ["XDG_CONFIG_HOME", "XDG_DATA_HOME",
                                     "XDG_STATE_HOME", "XDG_CACHE_HOME"])
def test_invalid_xdg_override(run, repo_root, home, env, variable):
    env[variable] = "relative/path"
    assert activate(run, repo_root, check=False).returncode != 0
    assert list(home.iterdir()) == []


def test_xdg_overrides_and_shell_escaping(run, repo_root, home, env, workspace):
    # These characters must remain literal, including in sourced startup hooks.
    for variable in ("HOME", "XDG_CONFIG_HOME", "XDG_DATA_HOME",
                     "XDG_STATE_HOME", "XDG_CACHE_HOME"):
        env[variable] = str(workspace / (variable + " space ' $ ` ;"))
    Path(env["HOME"]).mkdir()
    activate(run, repo_root)
    config = Path(env["XDG_CONFIG_HOME"])
    assert (config / "nvim").resolve() == repo_root / "nvim"
    assert (Path(env["XDG_DATA_HOME"]) / "opencode").is_dir()
    assert (Path(env["XDG_CACHE_HOME"]) / "opencode").is_dir()
    # Copy just the generated hooks to another home with harmless shell snippets;
    # the current shell snippets belong to a later step and are not yet guarded.
    sandbox = workspace / "shell home ' $ `"
    sandbox.mkdir()
    for name in (".bashrc", ".profile", ".zshrc"):
        shutil.copyfile(Path(env["HOME"]) / name, sandbox / name)
    snippets = sandbox / ".config/dotfiles"
    snippets.mkdir(parents=True)
    for name in ("bashrc", "zshrc"):
        (snippets / name).write_text('printf "hook-loaded\\n"\n')
    fallback = dict(env, HOME=str(sandbox))
    fallback.pop("XDG_CONFIG_HOME")
    for shell, name in (("bash", ".bashrc"), ("bash", ".profile"), ("zsh", ".zshrc")):
        result = run([shell, "-c", '. "$HOME/' + name + '"'], env=fallback)
        assert result.stdout == "hook-loaded\n"
    override = workspace / "config space ' $ `"
    shutil.copytree(sandbox / ".config", override)
    for shell, name in (("bash", ".bashrc"), ("zsh", ".zshrc")):
        result = run([shell, "-c", '. "$HOME/' + name + '"'],
                     env=dict(fallback, XDG_CONFIG_HOME=str(override)))
        assert result.stdout == "hook-loaded\n"
    assert list(home.iterdir()) == []


def test_rejects_repository_mutable_state(run, repo_root, env, home):
    env["XDG_STATE_HOME"] = str(repo_root / "nvim")
    result = activate(run, repo_root, check=False)
    assert result.returncode != 0 and "repository" in result.stderr
    assert list(home.iterdir()) == []


def test_opencode_credential_free_config_smoke(run, repo_root, home, env):
    before = snapshot(repo_root / "opencode")
    activate(run, repo_root)
    config = home / ".config/opencode"
    # Native generated config state must survive activation and stay off-repo.
    (config / "package.json").write_text('{"private":true}\n')
    (config / "node_modules").mkdir()
    (config / "node_modules/personal-state").write_text("preserve")
    activate(run, repo_root)
    assert (config / "node_modules/personal-state").read_text() == "preserve"
    env["OPENCODE_DISABLE_MODELS_FETCH"] = "true"
    result = run(["opencode", "debug", "config", "--pure"], timeout=60)
    resolved = json.loads(result.stdout)
    assert resolved["$schema"] == "https://opencode.ai/config.json"
    paths = run(["opencode", "debug", "paths", "--pure"])
    for variable in ("XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME", "XDG_CACHE_HOME"):
        assert env[variable] in paths.stdout
    assert snapshot(repo_root / "opencode") == before
