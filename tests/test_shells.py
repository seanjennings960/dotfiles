"""Exercise actual startup, directory statuses and terminal Tab completion."""

import json
import shlex
import time

import pytest


def startup(shell, repo_root, home, env):
    config = home / ".config/dotfiles"
    config.mkdir(parents=True)
    for name in ("bashrc", "bash_aliases", "zshrc"):
        (config / name).symlink_to(repo_root / name)
    snippet = config / ("bashrc" if shell == "bash" else "zshrc")
    block = f'source {shlex.quote(str(snippet))}\n'
    if shell == "bash":
        (home / ".bashrc").write_text(block)
        (home / ".bash_profile").write_text('source "$HOME/.bashrc"\n')
    else:
        # Ignore machine-global Zsh rc files; keep normal user startup behavior.
        (home / ".zshenv").write_text("unsetopt GLOBAL_RCS\n")
        (home / ".zshrc").write_text(block)
        env["ZDOTDIR"] = str(home)
    return snippet


def shell_args(shell):
    return (["--noprofile", "--norc"] if shell == "bash" else ["-f"])


@pytest.mark.parametrize("shell", ["bash", "zsh"])
def test_noninteractive_is_inert(shell, repo_root, run):
    file = repo_root / ("bashrc" if shell == "bash" else "zshrc")
    result = run([shell, *shell_args(shell), "-c",
                  (f'old=$PATH; source {file}; source {repo_root}/bash_aliases; '
                   'test "$old" = "$PATH"; printf "%s" "$?"')])
    assert result.stdout == "0"
    assert result.stderr == ""


@pytest.mark.parametrize("shell", ["bash", "zsh"])
@pytest.mark.parametrize("login", [False, True])
def test_startup_and_tab(shell, login, repo_root, home, env, workspace, run, terminal):
    snippet = startup(shell, repo_root, home, env)
    (workspace / "directory with spaces").mkdir()
    (workspace / "file with spaces.txt").write_text("completion target\n")
    run(["git", "init", "-q"])
    run(["git", "-c", "user.name=Test", "-c", "user.email=test@example.com",
         "commit", "--allow-empty", "-qm", "initial"])
    run(["git", "branch", "milestone-completion"])
    child = terminal(shell, ["-il" if login else "-i"])
    # Set a stable prompt after startup, then consume the actual prompt.
    child.sendline("PS1='DOT''S> '")
    child.expect_exact("DOTS> ")
    child.sendline("alias vim")
    child.expect_exact("vim=nvim" if shell == "zsh" else "vim='nvim'")
    child.expect_exact("DOTS> ")
    child.sendline(f"source {shlex.quote(str(snippet))}; source {shlex.quote(str(snippet))}")
    child.expect_exact("DOTS> ")
    assert "not found" not in child.before
    child.send("cd directory\t")
    child.sendline()
    child.expect_exact("DOTS> ")
    child.sendline("printf 'PATH_RESULT=%s\\n' \"$PWD\"")
    child.expect_exact(f"PATH_RESULT={workspace}/directory with spaces")
    child.expect_exact("DOTS> ")
    child.sendline("cd ..")
    child.expect_exact("DOTS> ")
    child.send("git checkout milestone-c\t")
    child.sendline()
    child.expect_exact("Switched to branch 'milestone-completion'")
    child.expect_exact("DOTS> ")
    child.sendline("git symbolic-ref --short HEAD")
    child.expect_exact("milestone-completion\r\n")
    child.expect_exact("DOTS> ")
    child.send("git add file\t")
    child.sendline()
    child.expect_exact("DOTS> ")
    assert run(["git", "diff", "--cached", "--name-only"]).stdout == "file with spaces.txt\n"


@pytest.mark.parametrize("shell", ["bash", "zsh"])
def test_status_logical_paths_and_idempotence(shell, repo_root, home, env, workspace, run):
    snippet = startup(shell, repo_root, home, env)
    fake_bin = workspace / "fake-bin"
    fake_bin.mkdir()
    log = workspace / "calls.jsonl"
    tmux = fake_bin / "tmux"
    tmux.write_text(
        '#!/usr/bin/python3\nimport json, os, sys\n'
        'with open(os.environ["TMUX_LOG"], "a") as log:\n'
        '    log.write(json.dumps(sys.argv[1:]) + "\\n")\n'
        'sys.exit(int(os.environ.get("TMUX_FAIL", "0")))\n'
    )
    tmux.chmod(0o755)
    target = workspace / "real directory"
    target.mkdir()
    logical = workspace / "linked directory"
    logical.symlink_to(target, target_is_directory=True)
    env.update(PATH=f"{fake_bin}:{env['PATH']}", TMUX="/tmp/fake,1,0",
               TMUX_PANE="%7", TMUX_LOG=str(log), DOTFILES_START_DIR=str(logical))
    # Start without rc then source the real symlink twice; venv stays first.
    script = f'''
source {shlex.quote(str(snippet))}
printf 'START=%s|%s\n' "$PWD" "${{DOTFILES_START_DIR-unset}}"
export PATH="/project/.venv/bin:$PATH"
source {shlex.quote(str(snippet))}
source {shlex.quote(str(snippet))}
printf 'BIN=%s\n' "$PATH"
builtin cd /missing-dotfiles-directory 2>/dev/null
expected=$?
cd /missing-dotfiles-directory 2>/dev/null
printf 'FAIL=%s|%s\n' "$?" "$expected"
export TMUX_FAIL=1
cd -- {shlex.quote(str(workspace))}
printf 'OK=%s|%s\n' "$?" "$PWD"
unset TMUX
cd -- {shlex.quote(str(logical))}
printf 'OUTSIDE=%s\n' "$PWD"
'''
    result = run([shell, *shell_args(shell), "-ic", script])
    assert f"START={logical}|unset" in result.stdout
    path = next(line[4:] for line in result.stdout.splitlines() if line.startswith("BIN="))
    assert path.startswith("/project/.venv/bin:")
    assert path.split(":").count(str(home / "bin")) == 1
    failure = next(line[5:] for line in result.stdout.splitlines() if line.startswith("FAIL="))
    actual, expected = failure.split("|")
    assert actual == expected and actual != "0"
    assert f"OK=0|{workspace}" in result.stdout
    assert f"OUTSIDE={logical}" in result.stdout
    calls = [json.loads(line) for line in log.read_text().splitlines()]
    assert calls
    assert all(call[:3] == ["set-environment", "-g", "TMUX_%7_PATH"] for call in calls)
    assert all(call[3] in (str(logical), str(workspace)) for call in calls)
    assert sum(call[3] == str(workspace) for call in calls) == 1
    if shell == "zsh":
        # Every successful change invokes one hook, even after repeated sourcing.
        assert len(calls) == 5
    else:
        assert len(calls) == 4


@pytest.mark.parametrize("shell", ["bash", "zsh"])
def test_quiet_optional_tools_and_local_hook(shell, repo_root, home, env, workspace, run):
    snippet = startup(shell, repo_root, home, env)
    config = home / ".config/dotfiles"
    local = config / f"local.{shell}"
    local.write_text('LOCAL_COUNT=$(( ${LOCAL_COUNT:-0} + 1 ))\n')
    # Only path resolution utilities exist; no tmux, nvim, or framework.
    tools = workspace / "tools"
    tools.mkdir()
    for name in ("realpath", "readlink"):
        (tools / name).symlink_to(f"/usr/bin/{name}")
    env["PATH"] = str(tools)
    env.update(TMUX="/tmp/missing,1,0", TMUX_PANE="%1")
    # Source shared settings directly to isolate missing-tool startup from completion.
    script = (f'source {repo_root}/bash_aliases; source {repo_root}/bash_aliases; '
              f'source {shlex.quote(str(local))}; printf "QUIET=%s" "$LOCAL_COUNT"')
    result = run([f"/usr/bin/{shell}", *shell_args(shell), "-ic", script])
    assert result.stdout == "QUIET=1"
    # Bash without a controlling terminal emits its own job-control diagnostics.
    assert "tmux" not in result.stderr and "not found" not in result.stderr
    env["PATH"] = "/usr/local/bin:/usr/bin:/bin"
    result = run([shell, *shell_args(shell), "-ic",
                  f'source {snippet}; source {snippet}; printf "%s" "$LOCAL_COUNT"'])
    assert result.stdout == "1"


@pytest.mark.parametrize("shell", ["bash", "zsh"])
def test_real_tmux_handoff(shell, repo_root, home, env, workspace, tmux_server):
    snippet = startup(shell, repo_root, home, env)
    target = workspace / "real"
    target.mkdir()
    logical = workspace / "logical space"
    logical.symlink_to(target, target_is_directory=True)
    script = f'source {shlex.quote(str(snippet))}; exec sleep 30'
    command = shlex.join([shell, *shell_args(shell), "-ic", script])
    tmux_server("-f", "/dev/null", "new-session", "-d", "-s", "shells",
                "-e", f"DOTFILES_START_DIR={logical}", command)
    # Poll the private server until startup publishes metadata.
    for _ in range(100):
        result = tmux_server("show-environment", "-g", "TMUX_%0_PATH", check=False)
        if result.returncode == 0:
            break
        time.sleep(0.05)
    assert result.stdout.strip() == f"TMUX_%0_PATH={logical}"
