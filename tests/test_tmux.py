"""Real bindings on a private tmux 3.4 server with an attached PTY client."""

import base64
import concurrent.futures
import shlex
import time
from types import SimpleNamespace

import pytest


def wait_for(probe, description):
    deadline = time.monotonic() + 8
    while time.monotonic() < deadline:
        result = probe()
        if result:
            return result
        time.sleep(0.02)
    pytest.fail(f"Timed out waiting for {description}")


@pytest.fixture
def session(repo_root, home, workspace, env, run, terminal, tmux_server):
    binary = home / "bin"
    binary.mkdir()
    (binary / "tmux_neww").symlink_to(repo_root / "tmux/tmux_neww.sh")
    env["PATH"] = f"{binary}:{env['PATH']}"
    (home / ".tmux.conf").symlink_to(repo_root / "tmux.conf")
    # Step 3 owns the real shell files. This independent Bash startup implements
    # the shared contract so tests verify child cwd, not just command arguments.
    rc = home / "tmux-test.bashrc"
    rc.write_text("""
if [[ -n ${DOTFILES_START_DIR-} ]]; then
    builtin cd -- "$DOTFILES_START_DIR" || exit
fi
unset DOTFILES_START_DIR
PROMPT_COMMAND='tmux set-environment -g "TMUX_${TMUX_PANE}_PATH" "$PWD"'
PS1='M1_READY> '
""")
    tmux_server("-f", home / ".tmux.conf", "new-session", "-d", "-s", "m1",
                "-c", workspace)
    shell = f"/bin/bash --noprofile --rcfile {shlex.quote(str(rc))}"
    tmux_server("set-option", "-g", "default-command", shell)
    tmux_server("respawn-pane", "-k", "-t", "%0", shell)
    client = terminal("tmux", ["-S", tmux_server.socket, "attach-session", "-t", "m1"])
    client.expect_exact("M1_READY> ")
    helper_env = dict(env)
    helper_env["TMUX"] = tmux_server("display-message", "-p", "-t", "%0",
                                       "#{socket_path},#{pid},0").stdout.strip()

    def panes():
        return tmux_server("list-panes", "-a", "-F", "#{pane_id}").stdout.splitlines()

    def path(pane):
        key = f"TMUX_{pane}_PATH"
        result = tmux_server("show-environment", "-g", key, check=False)
        return result.stdout.removeprefix(f"{key}=").rstrip("\n") if result.returncode == 0 else ""

    def create(mode, pane="%0", check=True):
        return run([repo_root / "tmux/tmux_neww.sh", mode, pane],
                   env=helper_env, check=check)

    def key(value):
        client.send("\x01" + value)

    return SimpleNamespace(tmux=tmux_server, client=client, panes=panes,
                           path=path, create=create, key=key, env=helper_env)


@pytest.mark.parametrize("binding,dimension", [("|", "width"), ("_", "height"), ("c", None)])
def test_creation_keys_preserve_logical_paths(session, workspace, binding, dimension):
    physical = workspace / "physical directory"
    physical.mkdir()
    logical = workspace / "logical link ' ; $(touch INJECTED)"
    logical.symlink_to(physical, target_is_directory=True)
    session.tmux("send-keys", "-t", "%0", f"cd -- {shlex.quote(str(logical))}", "Enter")
    wait_for(lambda: session.path("%0") == str(logical), "logical shell directory")
    original_size = int(session.tmux("display-message", "-p", "-t", "%0",
                                     f"#{{pane_{dimension or 'width'}}}").stdout)
    session.key(binding)
    wait_for(lambda: len(session.panes()) == 2, "creation binding")
    child = next(pane for pane in session.panes() if pane != "%0")
    wait_for(lambda: session.path(child) == str(logical), "child logical PWD")
    assert session.tmux("display-message", "-p", "-t", child,
                        "#{pane_current_path}").stdout.strip() == str(physical)
    if dimension:
        assert int(session.tmux("display-message", "-p", "-t", "%0",
                                f"#{{pane_{dimension}}}").stdout) < original_size
    else:
        assert len(session.tmux("list-windows", "-t", "m1").stdout.splitlines()) == 2
    assert not (workspace / "INJECTED").exists()
    session.tmux("send-keys", "-t", child,
                 'printf "CONSUMED:%s\\n" "${DOTFILES_START_DIR-unset}"', "Enter")
    wait_for(lambda: "CONSUMED:unset" in session.tmux("capture-pane", "-p", "-t", child).stdout,
             "startup variable consumed")
    assert session.tmux("show-environment", "-g", "DOTFILES_START_DIR", check=False).returncode
    assert session.tmux("show-environment", "-g", "NEWW", check=False).returncode


def test_prefix_forwarding_reaches_raw_program(session, workspace):
    received = workspace / "prefix-byte"
    program = workspace / "raw.py"
    program.write_text(
        "import os, tty\n"
        "tty.setraw(0)\n"
        "os.write(1, b'RAW_READY')\n"
        f"with open({str(received)!r}, 'wb') as result:\n"
        "    result.write(os.read(0, 1))\n"
        "    result.flush()\n"
        "    os.read(0, 1)\n"
    )
    session.tmux("respawn-pane", "-k", "-t", "%0", f"python3 {shlex.quote(str(program))}")
    session.client.expect_exact("RAW_READY")
    session.key("\x01")
    wait_for(lambda: received.exists() and received.read_bytes(), "forwarded prefix byte")
    assert received.read_bytes() == b"\x01"


@pytest.mark.parametrize("mode", ["-h", "-v", "-w"])
def test_requested_target_not_active_pane(session, workspace, mode):
    source = workspace / "source dir"
    source.mkdir()
    session.tmux("send-keys", "-t", "%0", f"cd -- {shlex.quote(str(source))}", "Enter")
    wait_for(lambda: session.path("%0") == str(source), "source cwd")
    session.tmux("new-session", "-d", "-s", "other", "-c", workspace)
    session.tmux("switch-client", "-t", "other")
    before = set(session.panes())
    session.create(mode)
    child = (set(session.panes()) - before).pop()
    wait_for(lambda: session.path(child) == str(source), "explicit target directory")
    assert session.tmux("display-message", "-p", "-t", child,
                        "#{session_name}").stdout.strip() == "m1"
    if mode != "-w":
        assert session.tmux("display-message", "-p", "-t", child,
                            "#{window_id}").stdout == session.tmux(
                                "display-message", "-p", "-t", "%0", "#{window_id}").stdout


@pytest.mark.parametrize("modes", [("-h", "-v"), ("-w", "-w"), ("-h", "-w")])
def test_simultaneous_requests_have_scoped_paths(session, workspace, modes):
    session.create("-w")
    parents = session.panes()
    paths = []
    for index, pane in enumerate(parents):
        physical = workspace / f"physical {index}"
        physical.mkdir()
        logical = workspace / f"logical {index}"
        logical.symlink_to(physical, target_is_directory=True)
        paths.append(str(logical))
        session.tmux("send-keys", "-t", pane, f"cd -- {shlex.quote(str(logical))}", "Enter")
        wait_for(lambda pane=pane, logical=logical: session.path(pane) == str(logical),
                 "parent logical cwd")
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        list(pool.map(lambda request: session.create(*request), zip(modes, parents)))
    children = set(session.panes()) - set(parents)
    wait_for(lambda: all(session.path(pane) for pane in children), "concurrent shell startup")
    assert sorted(session.path(pane) for pane in children) == sorted(paths)


@pytest.mark.parametrize("entry", [None, "", "relative", "missing", "dangling"])
def test_physical_fallback(session, workspace, entry):
    wait_for(lambda: session.path("%0"), "initial tracking")
    if entry is None:
        session.tmux("set-environment", "-gu", "TMUX_%0_PATH")
    else:
        path = entry
        if entry in ("missing", "dangling"):
            path = str(workspace / entry)
        if entry == "dangling":
            (workspace / entry).symlink_to(workspace / "absent")
        session.tmux("set-environment", "-g", "TMUX_%0_PATH", path)
    session.create("-h")
    wait_for(lambda: session.path("%1") == str(workspace), "physical fallback")


@pytest.mark.parametrize("args", [[], ["-h"], ["-x", "%0"], ["-h", "0"],
                                  ["-h", "%99999"], ["-h", "%0; true"],
                                  ["-h", "%0", "extra"], ["-h", "-w", "%0"]])
def test_invalid_arguments_fail(session, repo_root, run, args):
    before = session.panes()
    result = run([repo_root / "tmux/tmux_neww.sh", *args], env=session.env, check=False)
    assert result.returncode != 0
    assert session.panes() == before


def test_vi_navigation_resize_layout_and_reload(session):
    session.key("|")
    wait_for(lambda: len(session.panes()) == 2, "horizontal split")
    session.key("h")
    wait_for(lambda: session.tmux("display-message", "-p", "#{pane_id}").stdout.strip() == "%0",
             "vi left navigation")
    width = int(session.tmux("display-message", "-p", "-t", "%0", "#{pane_width}").stdout)
    session.key("\x0c")  # Ctrl-l
    wait_for(lambda: int(session.tmux("display-message", "-p", "-t", "%0",
                                     "#{pane_width}").stdout) > width, "vi resize")
    session.tmux("set-option", "-g", "repeat-time", "0")
    session.key("l")
    wait_for(lambda: session.tmux("display-message", "-p", "#{pane_id}").stdout.strip() == "%1",
             "vi right navigation")
    session.key("_")
    wait_for(lambda: len(session.panes()) == 3, "vertical split")
    session.key("k")
    wait_for(lambda: session.tmux("display-message", "-p", "#{pane_id}").stdout.strip() == "%1",
             "vi up navigation")
    session.key("j")
    wait_for(lambda: session.tmux("display-message", "-p", "#{pane_id}").stdout.strip() == "%2",
             "vi down navigation")
    session.key("\x1bh")  # Alt-h layout, leaving Ctrl-a free for forwarding.
    wait_for(lambda: session.tmux("display-message", "-p", "-t", "%0",
                                 "#{pane_width}").stdout == session.tmux(
                                     "display-message", "-p", "#{window_width}").stdout,
             "main-horizontal layout's full-width top pane")
    assert session.tmux("display-message", "-p", "-t", "%0", "#{pane_top}").stdout.strip() == "0"
    assert int(session.tmux("display-message", "-p", "-t", "%1", "#{pane_top}").stdout) > 0
    session.tmux("set-option", "-g", "prefix", "C-b")
    session.client.send("\x02r")
    wait_for(lambda: session.tmux("show-options", "-gv", "prefix").stdout.strip() == "C-a",
             "reload binding")


def test_vi_copy_emits_osc52_and_paste_uses_buffer(session):
    text = "OSC52_M1_COPY"
    session.tmux("send-keys", "-t", "%0", f"printf '{text}\\n'", "Enter")
    wait_for(lambda: session.tmux("capture-pane", "-p", "-t", "%0").stdout.rstrip().endswith(
                 f"{text}\nM1_READY>"),
             "copy source output")
    session.client.expect_exact(text)
    session.client.expect_exact("M1_READY> ")
    session.key("[")
    wait_for(lambda: session.tmux("display-message", "-p", "#{pane_in_mode}").stdout.strip() == "1",
             "copy mode")
    assert session.tmux("show-window-options", "-gv", "mode-keys").stdout.strip() == "vi"
    # Last output line: previous line, start, vi selection, end, yank.
    session.client.send("k")
    wait_for(lambda: session.tmux("display-message", "-p", "#{copy_cursor_y}").stdout.strip() == "1",
             "copy cursor up")
    session.client.send("0")
    wait_for(lambda: session.tmux("display-message", "-p", "#{copy_cursor_x}").stdout.strip() == "0",
             "copy cursor start")
    session.client.send("v")
    wait_for(lambda: session.tmux("display-message", "-p", "#{selection_present}").stdout.strip() == "1",
             "vi selection")
    session.client.send("e")
    wait_for(lambda: session.tmux("display-message", "-p", "#{copy_cursor_x}").stdout.strip() == str(len(text) - 1),
             "copy cursor end")
    session.client.send("y")
    encoded = base64.b64encode(text.encode()).decode()
    # tmux's clipboard feature uses an empty selection (terminal default).
    session.client.expect_exact(f"\x1b]52;;{encoded}\x07")
    assert session.tmux("show-buffer").stdout == text
    assert session.tmux("display-message", "-p", "#{pane_in_mode}").stdout.strip() == "0"
    session.key("P")
    wait_for(lambda: session.tmux("capture-pane", "-p", "-t", "%0").stdout.rstrip().endswith(
                 f"M1_READY> {text}"),
             "P pastes copied buffer")
