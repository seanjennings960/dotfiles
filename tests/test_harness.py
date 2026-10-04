"""Fixtures used by launcher and downstream terminal integration tests."""

import subprocess
import sys
import time

import pexpect
import pytest


def test_isolated_shell_input(terminal, env):
    child = terminal("/bin/bash", ["--noprofile", "--norc", "-i"], env={**env, "PS1": "DOTS> "})
    child.expect_exact("DOTS> ")
    child.sendline("printf 'HOME=%s\\n' \"$HOME\"")
    child.expect_exact(f"HOME={env['HOME']}\r\n")
    child.sendline("exit")
    child.expect(pexpect.EOF)


def test_timeout_cleans_up_descendants_holding_output(run):
    script = (
        "import subprocess, sys; "
        "subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(60)']); "
        "print('spawned', flush=True)"
    )
    started = time.monotonic()
    with pytest.raises(subprocess.TimeoutExpired) as error:
        run([sys.executable, "-c", script], timeout=0.5)
    assert "spawned" in error.value.output
    assert time.monotonic() - started < 5


def test_isolated_tmux_server(tmux_server):
    tmux_server("-f", "/dev/null", "new-session", "-d", "-s", "harness", "sleep 30")
    result = tmux_server("display-message", "-p", "#{session_name}")
    assert result.stdout.strip() == "harness"
