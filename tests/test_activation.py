"""Exercise production activation in isolated, non-root homes."""

import os
from pathlib import Path

import pytest


@pytest.fixture(autouse=True)
def activation_launcher(launcher, env):
    # Compatibility scripts use the installed wrapper even with an isolated HOME.
    env["DOTFILES_LAUNCHER"] = launcher[0]


def activate(run, repo_root, **kwargs):
    return run([repo_root / "install.sh"], **kwargs)


def snapshot(directory):
    return {str(p.relative_to(directory)): (p.read_bytes(), p.stat().st_mode)
            for p in directory.rglob("*") if p.is_file()}


def test_clean_nonroot_home_and_repeat(run, launcher, repo_root, home, env):
    assert os.getuid() != 0
    before = snapshot(repo_root / "opencode")
    nvim_before = snapshot(repo_root / "nvim")
    # dev activate locates personal source, not the invoking project's directory.
    run([*launcher, "activate"])
    config = Path(env["XDG_CONFIG_HOME"])
    links = {config / "nvim": repo_root / "nvim",
             config / "ghostty": repo_root / "ghostty",
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
    for script in ("install.sh", "infectdots.sh"):
        run([repo_root / script])
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
    assert (home / ".config/ghostty").resolve() == repo_root / "ghostty"
    assert (home / ".local/share/opencode").is_dir()
    assert (home / ".local/state/nvim/undo").is_dir()
    assert (home / ".cache/opencode").is_dir()
    assert trial.read_text() == "-- personal trial\n"
