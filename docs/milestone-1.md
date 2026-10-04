# Host launcher and feature handoff

The [roadmap](project.md) is the delivery order. PR #14 supplies the launcher and
repository test runner in the Ubuntu 24.04 ARM64 devcontainer. Personal tools and
activation follow in #15, shells in #16, Neovim in #17, tmux bindings in #18,
and languages in #19.
The devcontainer supplies Python 3.12, venv support, Make, and existing lightweight
tools. macOS installation, Homebrew packaging, and macOS installer adapters are
future work. Inside the development container, host mode means that container,
not the outer machine.

## Launcher contracts

- `dev --workspace PATH` overrides Git worktree discovery. Paths are canonicalized
  for identity, so a symlink to a worktree reconnects to the same workspace.
  Each linked worktree is a separate workspace. Discovery ignores inherited
  `GIT_*` overrides. An explicit directory need not be a Git project.
  If a mounted linked worktree's `.git` file points outside the container,
  discovery uses its boundary and inspection reports unavailable Git metadata.
- `Workspace.root` is the identity; `Workspace.cwd` is the invocation directory
  when inside the workspace, otherwise the root. These are `pathlib.Path` values
  passed as Click's context object. Future commands register on
  `dotfiles_dev.cli.cli` and use `@click.pass_obj`.
- Host tmux uses `-L dotfiles-dev`. Sessions carry `@dev_workspace` and
  `@dev_environment=host`. `Host.find`, `Host.ensure`, and `Host.enter` discover,
  create, and attach through tmux. A session rename does not change its identity.
  Reconnection does not reset pane directories or replace processes. Session
  name collisions with missing or different metadata fail.
- `DOTFILES_TMUX_SOCKET` explicitly selects a private socket for tests.
  No launcher process or separate session registry must remain alive.
- `dev exec` uses process replacement, not a shell command string. It inherits
  the caller's streams, terminal, signals, and project PATH. Missing executables
  return 127; non-executable commands return 126. Signal termination stays signal
  termination. Use `dev exec -- COMMAND` to end launcher option parsing.
- `DEV_ENVIRONMENT` is an invocation-local context marker. It defaults to `host`.
  Other values fail before entry, inspection or execution. Container entry and
  rebuild fail without host fallback. This marker is not an authorization boundary.
- Required tools are reported when missing. Entry requires tmux and a terminal;
  discovery requires Git unless the workspace is explicit. Inspection and exec
  do not need tmux. Entry never installs or activates personal defaults.

## Repository checks

`dev test` always changes to the dotfiles source, not the selected workspace.
Editable development uses the mounted checkout containing `dotfiles_dev`.
`DOTFILES_SOURCE` can explicitly select another packaged repository source.

The test environment lives at
`$XDG_CACHE_HOME/dotfiles/tests/<lock-digest>/bin/python`, defaulting to
`~/.cache`. Provision it explicitly with the launcher's Python:

```sh
make launcher-env test-env
dev test -q
dev test tests/test_launcher.py -k reconnect
```

Setup runs inside the container and uses its user-owned launcher virtualenv at
`~/.local/share/dotfiles/launcher`. The wrapper at `~/.local/bin/dev` uses that
Python with isolated import mode, while exec targets retain the caller's project
environment variables. `DOTFILES_TEST_PYTHON` selects an explicitly provisioned
test interpreter. The runner verifies direct and transitive distribution versions
against `requirements-dev.lock`, forwards pytest arguments including `--help`,
and preserves its exit status. It reports missing or mismatched dependencies
without fetching them. Version pins do not verify downloaded artifact hashes.

Feature tests go in `tests/test_<feature>.py`; pytest discovers them automatically.
Add test-only dependencies to the locked requirements and direct optional
dependencies in `pyproject.toml`. A lock change selects a new default environment.
Fixtures in `tests/conftest.py` supply isolated homes, XDG paths, workspaces,
subprocess groups, terminal input with transcripts, and private tmux servers.
Tests must state and check any extra personal-tool prerequisite explicitly.
The runner itself does not require Docker, Neovim, OpenCode, or language checkers.
Launcher integration tests require explicitly installed tmux.

## File ownership for the next PRs

- #15 adds tool management and activation modules, commands, installer delegation,
  personal selections, and ownership inspection. Packaged source is read-only
  configuration input; writable application state belongs outside it.
- #16 owns shell startup files and shell directory bookkeeping. The launcher
  preserves project executable precedence and leaves interactive startup to tmux.
- #17 owns `nvim/`, normal editor startup, and application state tests.
- #18 owns tmux config and helpers. Reuse `Host` and its metadata rather than
  introducing another lifecycle registry; add attached binding tests.
- #19 owns language commands and integrations with #15 and #17. Keep personal
  runtimes independent of project environments.

## Verification boundaries

Linux ARM64 tests as non-root `vscode` cover discovery, worktrees, cwd,
argument/stream/status forwarding, terminal input, tmux reconnection and persistent panes, unsupported
environments, missing prerequisites, and pytest forwarding/failures.
Tests invoke the production wrapper. A separate launcher dependency lock includes
Click and the editable-build prerequisites. Explicit devcontainer creation setup
provisions both environments without modifying host virtualenvs or global tools.
The Ubuntu image tag and apt packages are unpinned; package version locks do not
verify downloaded artifact hashes. Native macOS installation and verification
are deferred. Manual acceptance still includes terminal rendering and comfortable
attach/detach use. Clipboard delivery and personal startup checks belong to their
feature PRs.
