"""Isolated application fixtures shared by milestone integration tests."""

import io
import os
import signal
import shutil
import subprocess
import sys
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
        "LANG": "en_US.UTF-8" if sys.platform == "darwin" else "C.UTF-8",
        "LC_ALL": "en_US.UTF-8" if sys.platform == "darwin" else "C.UTF-8",
    }


@pytest.fixture
def run(env, workspace):
    def execute(args, *, check=True, **kwargs):
        kwargs.setdefault("env", env)
        kwargs.setdefault("cwd", workspace)
        timeout = kwargs.pop("timeout", 20)
        input_text = kwargs.pop("input", None)
        command = [str(arg) for arg in args]
        with subprocess.Popen(
            command, text=True, start_new_session=True,
            stdin=subprocess.PIPE if input_text is not None else subprocess.DEVNULL,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, **kwargs
        ) as process:
            try:
                stdout, stderr = process.communicate(input=input_text, timeout=timeout)
            except subprocess.TimeoutExpired as error:
                # A language server can outlive its editor and keep captured
                # pipes open. Kill the test command's entire private group.
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                stdout, stderr = process.communicate(timeout=5)
                error.output, error.stderr = stdout, stderr
                raise
        result = subprocess.CompletedProcess(command, process.returncode, stdout, stderr)
        if check:
            result.check_returncode()
        return result
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
    if shutil.which("tmux", path=env["PATH"]) is None:
        pytest.fail("Missing integration prerequisite: tmux. Install it explicitly.")
    # A short, private socket path also works with Unix socket path length limits.
    with tempfile.TemporaryDirectory(prefix="dots-tmux-") as directory:
        socket = str(Path(directory) / "socket")

        def tmux(*args, **kwargs):
            return run(["tmux", "-S", socket, *args], **kwargs)

        tmux.socket = socket
        yield tmux
        tmux("kill-server", check=False)


@pytest.fixture
def launcher(repo_root, env):
    env["PYTHONPATH"] = str(repo_root)
    executable = Path(os.environ.get("DOTFILES_LAUNCHER", Path.home() / ".local/bin/dev"))
    assert executable.is_file(), "Run explicit launcher setup before production CLI tests"
    return [str(executable)]
