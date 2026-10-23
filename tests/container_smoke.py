"""Exercise the installed launcher as the non-root container user."""

import errno
import json
import os
import pty
import select
import shutil
import signal
import subprocess
import termios
import time

import pytest


def run(arguments, cwd, environment):
    return subprocess.run(arguments, cwd=cwd, env=environment,
                          text=True, capture_output=True)


@pytest.fixture
def container_project(tmp_path):
    assert os.getuid() != 0, "Run the smoke check as the development user"
    dev = shutil.which("dev")
    assert dev, "The Feature must install dev on PATH"
    environment = dict(os.environ)
    assert environment.get("DEV_ENVIRONMENT") == "container"
    environment.pop("TMUX", None)
    environment["TERM"] = "xterm-256color"
    project = tmp_path / "project with spaces"
    project.mkdir()
    subprocess.run(["git", "init", "--quiet", str(project)], check=True)
    cwd = project / "nested"
    cwd.mkdir()
    environment["DOTFILES_TMUX_SOCKET"] = str(tmp_path / "tmux.sock")

    # A project venv without Click must not affect the launcher's runtime.
    venv = project / ".venv"
    subprocess.run(
        ["python3", "-m", "venv", "--without-pip", str(venv)], check=True,
    )
    environment["VIRTUAL_ENV"] = str(venv)
    environment["PATH"] = f"{venv / 'bin'}:{environment['PATH']}"

    try:
        yield dev, project, cwd, venv, environment
    finally:
        subprocess.run(
            ["tmux", "-S", environment["DOTFILES_TMUX_SOCKET"], "kill-server"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )


def test_environment_reports_workspace_and_invocation_directory(container_project):
    dev, project, cwd, _, environment = container_project
    result = run([dev, "env"], cwd, environment)
    assert result.returncode == 0, result.stderr
    assert "Environment: container" in result.stdout, result.stdout
    assert f"Workspace: {project}" in result.stdout, result.stdout
    assert f"Directory: {cwd}" in result.stdout, result.stdout


def test_exec_preserves_project_python_arguments_streams_and_status(container_project):
    dev, _, cwd, venv, environment = container_project
    result = run(
        [dev, "exec", "python", "-c", "import sys; print(sys.prefix)"], cwd, environment,
    )
    assert result.returncode == 0, result.stderr
    assert result.stdout.strip() == str(venv), result.stdout

    code = "import json, os, sys; print(json.dumps([os.getcwd(), sys.argv[1:]])); sys.stderr.write('stderr preserved'); sys.exit(7)"
    result = run([dev, "exec", "python", "-c", code, "a b", "--help"], cwd, environment)
    assert result.returncode == 7, result
    assert json.loads(result.stdout) == [str(cwd), ["a b", "--help"]]
    assert result.stderr == "stderr preserved", result.stderr


def test_launcher_ignores_project_python_environment_variables(container_project):
    dev, project, cwd, _, environment = container_project
    poison = project / "project python modules"
    poison.mkdir()
    (poison / "click.py").write_text("raise RuntimeError('project Click was imported')\n")
    environment["PYTHONPATH"] = str(poison)
    environment["PYTHONHOME"] = str(project / "nonexistent Python home")

    result = run([dev, "env"], cwd, environment)
    assert result.returncode == 0, result.stderr
    assert f"Workspace: {project}" in result.stdout, result.stdout


def enter_and_detach(dev, cwd, environment):
    """Run the installed entrypoint with a controlling terminal, then detach."""
    pid, terminal = pty.fork()
    if pid == 0:
        try:
            termios.tcsetwinsize(0, (24, 80))
            os.chdir(cwd)
            os.execvpe(dev, [dev], environment)
        except BaseException as error:
            os.write(2, str(error).encode())
            os._exit(127)

    tmux = ["tmux", "-S", environment["DOTFILES_TMUX_SOCKET"]]
    output = bytearray()
    reaped = False

    def drain_terminal():
        if select.select([terminal], [], [], 0.05)[0]:
            try:
                output.extend(os.read(terminal, 65536))
            except OSError as error:
                if error.errno != errno.EIO:
                    raise

    try:
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            drain_terminal()
            clients = run([*tmux, "list-clients", "-F", "#{session_id}"], cwd, environment)
            if clients.returncode == 0 and clients.stdout.strip():
                sessions = clients.stdout.splitlines()
                assert len(sessions) == 1, sessions
                session = sessions[0]
                break
            exited, status = os.waitpid(pid, os.WNOHANG)
            if exited:
                reaped = True
                pytest.fail(f"dev exited before attaching: {os.waitstatus_to_exitcode(status)}\n"
                            f"{output.decode(errors='replace')}")
        else:
            pytest.fail(f"dev did not attach to tmux:\n{output.decode(errors='replace')}")

        detached = run([*tmux, "detach-client", "-s", session], cwd, environment)
        assert detached.returncode == 0, detached.stderr
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            drain_terminal()
            exited, status = os.waitpid(pid, os.WNOHANG)
            if exited:
                reaped = True
                assert os.waitstatus_to_exitcode(status) == 0, output.decode(errors="replace")
                return session
        pytest.fail("dev did not exit after detaching from tmux")
    finally:
        if not reaped:
            os.kill(pid, signal.SIGKILL)
            os.waitpid(pid, 0)
        os.close(terminal)


def test_fresh_launcher_processes_reconnect_to_the_same_tmux_session(container_project):
    dev, _, cwd, _, environment = container_project
    tmux = ["tmux", "-S", environment["DOTFILES_TMUX_SOCKET"]]
    panes = [*tmux, "list-panes", "-a", "-F", "#{session_id}\t#{pane_id}\t#{pane_pid}"]

    first = enter_and_detach(dev, cwd, environment)
    first_panes = run(panes, cwd, environment)
    assert first_panes.returncode == 0 and first_panes.stdout.strip(), first_panes.stderr

    second = enter_and_detach(dev, cwd, environment)
    second_panes = run(panes, cwd, environment)
    assert first == second
    assert second_panes.returncode == 0, second_panes.stderr
    assert first_panes.stdout == second_panes.stdout
