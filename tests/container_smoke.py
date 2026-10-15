"""Exercise the installed launcher as the non-root container user."""

import json
import os
from pathlib import Path
import shutil
import subprocess

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


def test_fresh_launcher_processes_reconnect_to_the_same_tmux_session(container_project):
    dev, _, cwd, _, environment = container_project
    code = "from dotfiles_dev.local import Local; from dotfiles_dev.workspace import Workspace; print(Local('container').ensure(Workspace.discover()))"
    launcher_python = str(Path(dev).resolve().with_name("python"))
    first = run([launcher_python, "-I", "-c", code], cwd, environment)
    second = run([launcher_python, "-I", "-c", code], cwd, environment)
    assert first.returncode == second.returncode == 0, (first.stderr, second.stderr)
    assert first.stdout.strip() and first.stdout == second.stdout
