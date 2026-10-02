"""Prove the harness can exercise real applications without personal state."""

import json
import os
import platform
import subprocess
import time

import pexpect
import pytest


def test_baseline_toolchain(run):
    assert platform.system() == "Linux", "Run the baseline suite in Ubuntu"
    assert os.geteuid() != 0, "Run integration tests as the development user"
    expected = {
        "nvim": "NVIM v0.12.5",
        "ruff": "ruff 0.16.10",
        "pyright": "pyright 1.1.414",
        "opencode": "1.18.34",
    }
    for command, version in expected.items():
        result = run([command, "--version"])
        assert version in result.stdout
    assert run(["python", "--version"]).stdout.startswith("Python 3.12.")


def test_pyright_has_its_own_node_runtime(run, workspace, env):
    fake_bin = workspace / "bin"
    fake_bin.mkdir()
    node = fake_bin / "node"
    node.write_text("#!/bin/sh\nexit 77\n")
    node.chmod(0o755)
    result = run(["pyright", "--version"], env={**env, "PATH": f"{fake_bin}:{env['PATH']}"})
    assert "1.1.414" in result.stdout


def test_isolated_shell_input(terminal, env):
    child = terminal("bash", ["--noprofile", "--norc", "-i"], env={**env, "PS1": "DOTS> "})
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
        run(["python3", "-c", script], timeout=0.5)
    assert "spawned" in error.value.output
    assert time.monotonic() - started < 5


def test_isolated_tmux_server(tmux_server):
    tmux_server("-f", "/dev/null", "new-session", "-d", "-s", "harness", "sleep 30")
    result = tmux_server("display-message", "-p", "#{session_name}")
    assert result.stdout.strip() == "harness"


def test_neovim_can_write_in_isolated_home(run, home, workspace):
    document = workspace / "example.py"
    result = run([
        "nvim", "--headless", "-u", "NONE", document,
        "+lua vim.api.nvim_buf_set_lines(0, 0, -1, false, {'answer = 42'})",
        "+write", "+quit",
    ])
    assert document.read_text() == "answer = 42\n"
    assert "Error" not in result.stderr
    assert home.is_dir()


def test_report_environment(run):
    report = {
        "platform": platform.platform(),
        "architecture": platform.machine(),
        "python": run(["python", "--version"]).stdout.strip(),
        "tmux": run(["tmux", "-V"]).stdout.strip(),
    }
    print(json.dumps(report, indent=2))
