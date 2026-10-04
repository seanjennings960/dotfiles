"""Production CLI checks for discovery, process replacement and host persistence."""

import json
from pathlib import Path
import signal
import sys
import time

import pexpect
import pytest
import click

from dotfiles_dev import testing
from dotfiles_dev.host import Host, WORKSPACE_OPTION, ENVIRONMENT_OPTION
from dotfiles_dev.workspace import Workspace


def git(run, workspace, *args):
    return run(["git", "-C", workspace, *args])


def test_outside_project(run, launcher, workspace):
    report = run([*launcher, "env"]).stdout
    assert f"Workspace: {workspace.resolve()}" in report
    assert f"Directory: {workspace.resolve()}" in report
    assert "Environment: host" in report


def test_git_discovery_and_invocation_directory(run, launcher, workspace, env):
    git(run, workspace, "init")
    nested = workspace / "nested directory"
    nested.mkdir()
    env["GIT_DIR"] = "/nonexistent"
    report = run([*launcher, "env"], cwd=nested).stdout
    assert f"Workspace: {workspace.resolve()}" in report
    assert f"Directory: {nested.resolve()}" in report


def test_distinct_worktree(run, launcher, workspace, tmp_path):
    git(run, workspace, "init")
    git(run, workspace, "-c", "user.name=Test", "-c", "user.email=test@example.org",
        "commit", "--allow-empty", "-m", "Initial")
    other = tmp_path / "another worktree"
    git(run, workspace, "worktree", "add", "-b", "other", other)
    report = run([*launcher, "env"], cwd=other).stdout
    assert f"Workspace: {other.resolve()}" in report


def test_mounted_worktree_with_unreachable_git_metadata(run, launcher, workspace):
    (workspace / ".git").write_text("gitdir: /unreachable/host/repo/.git/worktrees/example\n")
    nested = workspace / "nested"
    nested.mkdir()
    report = run([*launcher, "env"], cwd=nested).stdout
    assert f"Workspace: {workspace.resolve()}" in report
    assert f"Directory: {nested.resolve()}" in report
    assert "Git metadata: unavailable" in report


@pytest.mark.parametrize("inside", [True, False])
def test_explicit_workspace(run, launcher, workspace, tmp_path, inside):
    nested = workspace / "sub"
    nested.mkdir()
    cwd = nested if inside else tmp_path
    report = run([*launcher, "--workspace", workspace, "env"], cwd=cwd).stdout
    expected = nested if inside else workspace
    assert f"Directory: {expected.resolve()}" in report


def test_explicit_symlink_identity(run, launcher, workspace, tmp_path):
    link = tmp_path / "alias"
    link.symlink_to(workspace, target_is_directory=True)
    report = run([*launcher, "--workspace", link, "env"]).stdout
    assert f"Workspace: {workspace.resolve()}" in report


def test_missing_workspace(run, launcher, tmp_path):
    result = run([*launcher, "--workspace", tmp_path / "missing", "env"], check=False)
    assert result.returncode != 0
    assert "not a directory" in result.stderr


def test_exec_arguments_streams_cwd_and_status(run, launcher, workspace):
    script = (
        "import json, os, sys; "
        "print(json.dumps([os.getcwd(), sys.argv[1:], sys.stdin.read()])); "
        "print('diagnostic', file=sys.stderr); sys.exit(23)"
    )
    args = ["space value", "", "$(touch never)", "--flag", "--help", "a'b", "line\nbreak"]
    result = run([*launcher, "exec", sys.executable, "-c", script, *args],
                 input="input data\n", check=False)
    assert result.returncode == 23
    assert json.loads(result.stdout) == [str(workspace.resolve()), args, "input data\n"]
    assert result.stderr == "diagnostic\n"
    assert not (workspace / "never").exists()


def test_exec_explicit_root_cwd(run, launcher, workspace, tmp_path):
    result = run([*launcher, "--workspace", workspace, "exec", "/bin/pwd"], cwd=tmp_path)
    assert result.stdout.strip() == str(workspace.resolve())


def test_exec_preserves_project_path(run, launcher, workspace, env):
    binary = workspace / "project-command"
    binary.write_text("#!/bin/sh\nprintf project-command")
    binary.chmod(0o755)
    env["PATH"] = f"{workspace}:{env['PATH']}"
    env["VIRTUAL_ENV"] = str(workspace)
    assert run([*launcher, "exec", "project-command"]).stdout == "project-command"


def test_launcher_ignores_project_python_settings(run, launcher, env, workspace):
    (workspace / "click.py").write_text("raise RuntimeError('project import leaked into launcher')")
    env["PYTHONPATH"] = str(workspace)
    env["PYTHONHOME"] = "/missing/project/python"
    env["VIRTUAL_ENV"] = str(workspace)
    assert "Environment: host" in run([*launcher, "env"]).stdout
    # The exec target still receives project-specific environment variables.
    result = run([*launcher, "exec", "/usr/bin/env"])
    assert "PYTHONHOME=/missing/project/python" in result.stdout


@pytest.mark.parametrize("command,status", [("missing-command-12345", 127), ("./blocked", 126)])
def test_exec_missing_or_unexecutable(run, launcher, workspace, command, status):
    (workspace / "blocked").write_text("not executable")
    result = run([*launcher, "exec", command], check=False)
    assert result.returncode == status
    assert result.stderr


def test_exec_preserves_signal_status(run, launcher):
    result = run([*launcher, "exec", sys.executable, "-c",
                  "import os, signal; os.kill(os.getpid(), signal.SIGTERM)"], check=False)
    assert result.returncode == -signal.SIGTERM


def test_exec_terminal_input(terminal, launcher):
    script = "import os; print('TTY', os.isatty(0), os.isatty(1), os.isatty(2)); print(input())"
    child = terminal(launcher[0], [*launcher[1:], "exec", sys.executable, "-c", script])
    child.expect_exact("TTY True True True")
    child.sendline("terminal input")
    child.expect_exact("terminal input\r\n")
    child.expect(pexpect.EOF)
    child.close()
    assert child.exitstatus == 0


@pytest.mark.parametrize("args", [["env", "enter", "container"], ["env", "rebuild"],
                                  ["--environment", "container", "exec", "/bin/echo", "NEVER"]])
def test_container_requests_do_not_run_host(run, launcher, args):
    result = run([*launcher, *args], check=False)
    assert result.returncode != 0
    assert "NEVER" not in result.stdout


def test_container_context_cannot_execute(run, launcher, env):
    env["DEV_ENVIRONMENT"] = "container"
    result = run([*launcher, "exec", "/bin/echo", "NEVER"], check=False)
    assert result.returncode != 0
    assert "Unsupported environment" in result.stderr
    assert not result.stdout


def test_entry_requires_terminal(run, launcher, tmux_server, env):
    env["DOTFILES_TMUX_SOCKET"] = tmux_server.socket
    result = run(launcher, check=False)
    assert "interactive terminal" in result.stderr
    assert tmux_server("list-sessions", check=False).returncode != 0


def test_missing_tmux_reports_without_install(run, launcher, env):
    env["PATH"] = "/nonexistent"
    result = run([*launcher, "--workspace", ".", "env", "enter", "host"], check=False)
    assert "Missing tool: tmux" in result.stderr


def test_tmux_inspection_failure_stops_entry(terminal, launcher, workspace, env):
    binary = workspace / "tmux"
    binary.write_text("#!/bin/sh\necho 'tmux inspection denied' >&2\nexit 1\n")
    binary.chmod(0o755)
    env["PATH"] = f"{workspace}:{env['PATH']}"
    child = terminal(launcher[0], ["--workspace", workspace, "env", "enter", "host"])
    child.expect_exact("tmux inspection denied")
    child.expect(pexpect.EOF)
    child.close()
    assert child.exitstatus == 1


def test_reconnect_discovers_metadata_and_keeps_directory(tmux_server, workspace, env, monkeypatch):
    monkeypatch.setenv("DOTFILES_TMUX_SOCKET", tmux_server.socket)
    tmux_server("-f", "/dev/null", "new-session", "-d", "-s", "renamed", "-c", str(workspace), "sleep 60")
    tmux_server("set-option", "-t", "renamed", WORKSPACE_OPTION, str(workspace.resolve()))
    tmux_server("set-option", "-t", "renamed", ENVIRONMENT_OPTION, "host")
    before = tmux_server("list-panes", "-t", "renamed", "-F", "#{pane_pid}:#{pane_current_path}").stdout
    session = Host().ensure(Workspace(workspace.resolve(), workspace.parent.resolve()))
    assert session.startswith("$")
    assert before == tmux_server("list-panes", "-t", "renamed", "-F", "#{pane_pid}:#{pane_current_path}").stdout
    assert tmux_server("list-sessions").stdout.count("\n") == 1


def test_host_sessions_distinguish_workspaces(tmux_server, workspace, tmp_path, monkeypatch):
    monkeypatch.setenv("DOTFILES_TMUX_SOCKET", tmux_server.socket)
    first = Host().ensure(Workspace(workspace.resolve(), workspace.resolve()))
    other = tmp_path / "other"
    other.mkdir()
    second = Host().ensure(Workspace(other.resolve(), other.resolve()))
    assert first != second
    assert Host().find(Workspace(workspace.resolve(), workspace.resolve())) == first


def test_session_collision_does_not_adopt_container(tmux_server, workspace, monkeypatch):
    monkeypatch.setenv("DOTFILES_TMUX_SOCKET", tmux_server.socket)
    context = Workspace(workspace.resolve(), workspace.resolve())
    session = Host().ensure(context)
    tmux_server("set-option", "-t", session, ENVIRONMENT_OPTION, "container")
    with pytest.raises(click.ClickException, match="duplicate session"):
        Host().ensure(context)
    assert tmux_server("show-options", "-qv", "-t", session, ENVIRONMENT_OPTION).stdout.strip() == "container"


def test_exiting_one_shell_keeps_other_panes(tmux_server, workspace, monkeypatch):
    monkeypatch.setenv("DOTFILES_TMUX_SOCKET", tmux_server.socket)
    session = Host().ensure(Workspace(workspace.resolve(), workspace.resolve()))
    tmux_server("split-window", "-d", "-t", session, "sleep 60")
    tmux_server("send-keys", "-t", session + ":0.0", "exit", "Enter")
    # Ask tmux to wait for the shell exit rather than assuming a scheduling delay.
    for _ in range(100):
        panes = tmux_server("list-panes", "-t", session, "-F", "#{pane_current_command}").stdout.splitlines()
        if panes == ["sleep"]:
            break
        time.sleep(0.01)
    assert panes == ["sleep"]
    assert Host().find(Workspace(workspace.resolve(), workspace.resolve())) == session


def test_fresh_launcher_attaches_detaches_and_reconnects(terminal, launcher, tmux_server, env, workspace):
    env["DOTFILES_TMUX_SOCKET"] = tmux_server.socket
    # Start the server without user config, then let production entry create its session.
    tmux_server("-f", "/dev/null", "new-session", "-d", "-s", "fixture", "sleep 60")
    for command in ([], ["env", "enter", "host"]):
        child = terminal(launcher[0], [*launcher[1:], *command])
        # Wait for entry, then inspect the actual persistent session independently.
        child.expect(r"\[dev-host-")
        sessions = tmux_server("list-sessions", "-F", "#{session_id}").stdout.splitlines()
        managed = [session for session in sessions if tmux_server(
            "show-options", "-qv", "-t", session, WORKSPACE_OPTION).stdout.strip() == str(workspace.resolve())]
        assert len(managed) == 1
        current = tmux_server("list-panes", "-t", managed[0], "-F", "#{pane_pid}").stdout
        if command:
            assert current == previous
        previous = current
        child.sendcontrol("b")
        child.send("d")
        child.expect(pexpect.EOF)
        child.close()
        assert child.exitstatus == 0


def test_test_runner_missing_environment(run, launcher, env):
    env["DOTFILES_TEST_PYTHON"] = "/missing/test/python"
    result = run([*launcher, "test"], check=False)
    assert result.returncode == 1
    assert "Missing test environment" in result.stderr


def test_test_runner_rejects_unlocked_environment(run, launcher, env, workspace):
    fake = workspace / "python"
    fake.write_text("#!/bin/sh\necho wrong-lock >&2\nexit 1\n")
    fake.chmod(0o755)
    env["DOTFILES_TEST_PYTHON"] = str(fake)
    result = run([*launcher, "test"], check=False)
    assert result.returncode == 1
    assert "differs from the lock" in result.stderr


@pytest.mark.parametrize("args,status", [(["-q", "-k", "test_pass"], 0),
                                        (["-q", "-k", "test_fail"], 1),
                                        (["--invalid-runner-option"], 4),
                                        (["--help"], 0)])
def test_test_runner_forwards_arguments_and_status(run, launcher, env, workspace, args, status):
    source = workspace / "repository"
    (source / "tests").mkdir(parents=True)
    (source / "tests" / "test_sample.py").write_text(
        "def test_pass():\n    assert True\ndef test_fail():\n    assert False\n")
    real_source = Path(__file__).resolve().parents[1]
    (source / "requirements-dev.lock").write_bytes((real_source / "requirements-dev.lock").read_bytes())
    env["DOTFILES_SOURCE"] = str(source)
    env["DOTFILES_TEST_PYTHON"] = sys.executable
    result = run([*launcher, "test", *args], check=False)
    assert result.returncode == status
    if "test_pass" in args:
        assert "1 passed" in result.stdout
    if "test_fail" in args:
        assert "1 failed" in result.stdout
    if "--help" in args:
        assert "pytest" in result.stdout


def test_test_cache_depends_on_lock(tmp_path, monkeypatch):
    monkeypatch.setenv("DOTFILES_SOURCE", str(tmp_path))
    monkeypatch.setenv("XDG_CACHE_HOME", str(tmp_path / "cache"))
    monkeypatch.delenv("DOTFILES_TEST_PYTHON", raising=False)
    lock = tmp_path / "requirements-dev.lock"
    lock.write_text("pytest==8.4.2\n")
    before = testing.test_python()
    lock.write_text("pytest==8.4.3\n")
    assert testing.test_python() != before


def test_test_interpreter_override_keeps_virtualenv_symlink(tmp_path, monkeypatch):
    executable = tmp_path / "venv" / "bin" / "python"
    executable.parent.mkdir(parents=True)
    executable.symlink_to(sys.executable)
    monkeypatch.setenv("DOTFILES_TEST_PYTHON", str(executable))
    assert testing.test_python() == executable
