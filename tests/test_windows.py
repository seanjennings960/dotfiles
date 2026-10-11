"""Window moves operate on stable IDs and retain processes and primary identity."""

import json
import time
from pathlib import Path

import pexpect
import pytest

from dotfiles_dev.local import ENVIRONMENT_OPTION, WORKSPACE_OPTION, Local
from dotfiles_dev.workspace import Workspace


@pytest.fixture
def session(tmux_server, env, workspace, monkeypatch):
    env["DOTFILES_TMUX_SOCKET"] = tmux_server.socket
    monkeypatch.setenv("DOTFILES_TMUX_SOCKET", tmux_server.socket)
    local = Local("host")
    context = Workspace(workspace.resolve(), workspace.resolve())
    source = local.ensure(context)
    tmux_server("new-window", "-d", "-t", source)
    tmux_server("new-window", "-d", "-t", source)
    pane = tmux_server("display-message", "-p", "-t", source, "#{pane_id}").stdout.strip()
    return local, context, source, pane


@pytest.mark.parametrize("indexes", [(0,), (0, 2), (0, 1, 2)])
def test_pop_keeps_panes_and_primary(run, launcher, tmux_server, session, indexes):
    local, context, source, pane = session
    before = set(tmux_server("list-panes", "-a", "-F", "#{pane_id}:#{pane_pid}").stdout.splitlines())
    result = run([*launcher, "windows", "pop", "--pane", pane, *map(str, indexes)])
    assert "Moved" in result.stdout
    after = set(tmux_server("list-panes", "-a", "-F", "#{pane_id}:#{pane_pid}").stdout.splitlines())
    assert before == after
    primary = local.find(context)
    assert primary
    assert (primary != source) == (len(indexes) == 3)
    assert local.metadata(primary, WORKSPACE_OPTION) == str(context.root)
    assert local.metadata(primary, ENVIRONMENT_OPTION) == "host"


@pytest.mark.parametrize("indexes", [[], ["0", "0"], ["9"], ["-1"], ["garbage"]])
def test_invalid_pop_preserves_sessions(run, launcher, tmux_server, session, indexes):
    _, _, _, pane = session
    before = tmux_server("list-panes", "-a", "-F", "#{session_id}:#{pane_id}:#{pane_pid}").stdout
    result = run([*launcher, "windows", "pop", "--pane", pane, *indexes], check=False)
    assert result.returncode != 0
    assert tmux_server("list-panes", "-a", "-F", "#{session_id}:#{pane_id}:#{pane_pid}").stdout == before


@pytest.mark.parametrize("valid", [True, False])
def test_pop_prompt_and_fresh_launcher_reconnect(run, launcher, terminal, tmux_server, env, workspace, tmp_path, valid):
    env["DOTFILES_TMUX_SOCKET"] = tmux_server.socket
    shim = tmp_path / "bin"
    shim.mkdir()
    arguments = tmp_path / "arguments.json"
    executable = shim / "dev"
    executable.write_text(
        "#!/usr/bin/python3\nimport json, os, sys\n"
        f"with open({str(arguments)!r}, 'w') as output: json.dump(sys.argv[1:], output)\n"
        f"os.execv({launcher[0]!r}, [{launcher[0]!r}, *sys.argv[1:]])\n"
    )
    executable.chmod(0o755)
    env["PATH"] = str(shim) + ":" + str(Path(launcher[0]).parent) + ":" + env["PATH"]
    run([*launcher, "activate"])
    child = terminal(launcher[0])
    child.expect(r"\[dev-host-")
    source = tmux_server("display-message", "-p", "#{session_id}").stdout.strip()
    tmux_server("new-window", "-d", "-t", source)
    before = set(tmux_server("list-panes", "-a", "-F", "#{pane_id}:#{pane_pid}").stdout.splitlines())
    child.sendcontrol("a")
    child.send("g")
    child.expect("Window indexes")
    marker = workspace / "injected"
    selection = "0 1" if valid else f"0 \" ' ; $(touch {marker}) #{{pane_id}} }}"
    child.send(selection + "\r")
    child.expect(pexpect.TIMEOUT, timeout=0.5)
    deadline = time.monotonic() + 3
    while not arguments.exists() and time.monotonic() < deadline:
        time.sleep(0.05)
    captured = json.loads(arguments.read_text())
    assert captured[-2:] == ["--select", selection]
    if not valid:
        assert not marker.exists()
        assert tmux_server("list-sessions", "-F", "#{session_id}").stdout.splitlines() == [source]
        assert before == set(tmux_server("list-panes", "-a", "-F", "#{pane_id}:#{pane_pid}").stdout.splitlines())
        return
    deadline = time.monotonic() + 8
    while time.monotonic() < deadline:
        sessions = tmux_server("list-sessions", "-F", "#{session_id}").stdout.splitlines()
        if len(sessions) == 1 and source not in sessions:
            break
        time.sleep(0.05)
    assert len(sessions) == 1 and source not in sessions, (
        json.loads(arguments.read_text()) if arguments.exists() else "launcher not invoked",
        child.before, tmux_server("show-messages").stdout,
        tmux_server("list-keys", "-T", "prefix", "g").stdout)
    destination = sessions[0]
    assert tmux_server("show-options", "-v", "-t", destination, WORKSPACE_OPTION).stdout.strip() == str(workspace)
    assert before == set(tmux_server("list-panes", "-a", "-F", "#{pane_id}:#{pane_pid}").stdout.splitlines())
    child.sendcontrol("a")
    child.send("d")
    child.expect(pexpect.EOF)
    child.close()
    child = terminal(launcher[0])
    child.expect(r"\[1\]")
    assert tmux_server("list-sessions", "-F", "#{session_id}").stdout.splitlines() == [destination]
    assert tmux_server("list-clients", "-F", "#{session_id}").stdout.splitlines() == [destination]
    child.sendcontrol("a")
    child.send("d")
    child.expect(pexpect.EOF)
