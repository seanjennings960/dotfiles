"""Exercise the packaged configuration through real terminal input."""

import os
from pathlib import Path
import re
import subprocess
import time
import uuid

import pytest


def test_prefix_ctrl_s_saves_resurrect_snapshot(tmp_path):
    executable = os.environ.get("DOTFILES_TEST_TMUX")
    if not executable:
        pytest.skip("Set DOTFILES_TEST_TMUX to the Nix-packaged tmux executable")
    assert Path(executable).is_file(), executable
    import pexpect

    home = tmp_path / "home"
    workspace = tmp_path / "workspace with spaces"
    home.mkdir()
    workspace.mkdir()
    env = {
        **os.environ,
        "HOME": str(home),
        "XDG_CONFIG_HOME": str(home / "config"),
        "XDG_CACHE_HOME": str(home / "cache"),
        "XDG_DATA_HOME": str(home / "data"),
        "XDG_STATE_HOME": str(home / "state"),
        "TERM": "xterm-256color",
    }
    env.pop("TMUX", None)
    env.pop("TMUX_TMPDIR", None)
    # A short, unique socket name also works with macOS's Unix socket path limit.
    command = [executable, "-L", "resurrect-test-" + uuid.uuid4().hex[:12]]

    def tmux(*args):
        return subprocess.run(
            [*command, *args], env=env, text=True, capture_output=True, timeout=10,
        )

    def wait_for(predicate, description):
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            if predicate():
                return
            assert client.isalive(), "Attached tmux client exited unexpectedly"
            time.sleep(0.05)
        pytest.fail(description)

    client = pexpect.spawn(
        command[0], [*command[1:], "new-session", "-s", "shortcut-test", "-c", str(workspace)],
        env=env, encoding="utf-8", dimensions=(30, 120), timeout=15,
    )
    try:
        wait_for(
            lambda: tmux("show-option", "-gv", "@resurrect-save-script-path").returncode == 0,
            "tmux-resurrect did not load from the packaged configuration",
        )
        assert tmux("show-option", "-gv", "prefix").stdout.strip() == "C-a"
        bindings = tmux("list-keys", "-T", "prefix").stdout
        assert re.search(r"\bC-s\s+run-shell\b[^\n]*scripts/save\.sh", bindings), bindings
        split = tmux("split-window", "-hd", "-t", "shortcut-test", "-c", str(workspace))
        assert split.returncode == 0, split.stderr
        wait_for(
            lambda: tmux("list-panes", "-t", "shortcut-test", "-F", "#{pane_current_path}")
            .stdout.splitlines() == [str(workspace), str(workspace)],
            "Both pane shells did not finish starting in the workspace",
        )

        snapshot = home / ".tmux" / "resurrect" / "last"
        assert not snapshot.exists()
        # Send actual keystrokes to the attached client, not send-keys (which
        # targets a pane) and not the plugin's save script directly.
        client.sendcontrol("a")
        client.sendcontrol("s")
        wait_for(snapshot.is_file, "Ctrl-A followed by Ctrl-S did not create a snapshot")
        panes = [line.split("\t") for line in snapshot.read_text().splitlines()
                 if line.startswith("pane\tshortcut-test\t")]
        assert len(panes) == 2, snapshot.read_text()
        assert all(pane[7].replace("\\ ", " ") == ":" + str(workspace) for pane in panes), panes
    finally:
        tmux("kill-server")
        client.close(force=True)
