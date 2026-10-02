"""Isolated application fixtures shared by milestone integration tests."""

import io
import subprocess
import tempfile
from pathlib import Path

import pexpect
import pytest


@pytest.fixture
def repo_root():
    return Path(__file__).resolve().parents[1]


@pytest.fixture
def home(tmp_path):
    path = tmp_path / "home"
    path.mkdir()
    return path


@pytest.fixture
def workspace(tmp_path):
    path = tmp_path / "workspace"
    path.mkdir()
    return path


@pytest.fixture
def env(home):
    # Do not inherit credentials, application configuration, TMUX, or a host venv.
    return {
        "HOME": str(home),
        "XDG_CONFIG_HOME": str(home / ".config"),
        "XDG_DATA_HOME": str(home / ".local/share"),
        "XDG_STATE_HOME": str(home / ".local/state"),
        "XDG_CACHE_HOME": str(home / ".cache"),
        "PATH": "/usr/local/bin:/usr/bin:/bin",
        "TERM": "xterm-256color",
        "LANG": "C.UTF-8",
        "LC_ALL": "C.UTF-8",
    }


@pytest.fixture
def run(env, workspace):
    def execute(args, *, check=True, **kwargs):
        kwargs.setdefault("env", env)
        kwargs.setdefault("cwd", workspace)
        kwargs.setdefault("timeout", 20)
        return subprocess.run(
            [str(arg) for arg in args], check=check, text=True,
            capture_output=True, **kwargs
        )
    return execute


@pytest.fixture
def terminal(env, workspace, tmp_path):
    children = []

    def spawn(command, args=(), **kwargs):
        kwargs.setdefault("env", env)
        kwargs.setdefault("cwd", str(workspace))
        kwargs.setdefault("timeout", 15)
        child = pexpect.spawn(
            str(command), [str(arg) for arg in args], encoding="utf-8",
            dimensions=(24, 100), **kwargs
        )
        transcript = io.StringIO()
        child.logfile_read = transcript
        children.append((child, transcript))
        return child

    yield spawn
    for index, (child, transcript) in enumerate(children):
        child.close(force=True)
        log = tmp_path / f"terminal-{index}.log"
        log.write_text(transcript.getvalue())
        print(f"Terminal transcript: {log}\n{transcript.getvalue()}")


@pytest.fixture
def tmux_server(env, run):
    # A short, private socket path also works with Unix socket path length limits.
    with tempfile.TemporaryDirectory(prefix="dots-tmux-") as directory:
        socket = str(Path(directory) / "socket")

        def tmux(*args, **kwargs):
            return run(["tmux", "-S", socket, *args], **kwargs)

        tmux.socket = socket
        yield tmux
        tmux("kill-server", check=False)
