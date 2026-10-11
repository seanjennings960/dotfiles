# Dotfiles

Personal terminal configuration and a Python/Click workspace launcher. See the
[architecture](docs/architecture.md) for the design and the
[roadmap](docs/project.md) for the remaining work.

## Set up the baseline

The supported development environment is Ubuntu 24.04 ARM64 with Python 3.12,
running as non-root `vscode` in this repository's devcontainer. Its personal
[devtools Feature](features/README.md) installs the launcher, Neovim, Ruff,
Pyright, OpenCode, tmux, Bash completion, and Zsh. The project Dockerfile supplies
test/build prerequisites. `dev env` reports `container` inside this image;
native macOS launcher installation and Homebrew packaging follow later.

Install Docker and the Dev Container CLI, then run from the repository root:

```sh
git submodule sync --recursive
git submodule update --init --recursive --checkout
devcontainer up --workspace-folder .
devcontainer exec --workspace-folder . dev test -q --opencode
devcontainer exec --workspace-folder . bash
```

VS Code's **Dev Containers: Reopen in Container** runs the same setup. The
initialize hook stages a self-contained Feature with the recorded plugin
checkouts. Build installs it under `/opt/dotfiles-dev`; `/usr/local/bin/dev`
uses its private Python with isolated imports. Creation runs `dev activate &&
make test-env`, which explicitly provisions locked test dependencies in
`~/.cache/dotfiles/tests`. Project virtualenvs do not select the launcher runtime.

After creation, start a fresh shell. Repeat activation whenever needed:

```sh
dev activate
exec bash
dev env
dev
```

Activation is offline and repeatable. It links configuration and adds managed
startup blocks while preserving existing personal content. Conflicts fail before
changes; see [activation and migration](docs/activation.md) for destinations and
legacy-link handling. `./install.sh` and `./infectdots.sh` delegate to `dev activate`.
Entry and testing never install or activate anything.

The mounted checkout and installed Feature are separate: rebuild to test an
updated packaged source snapshot. For an editable launcher during development,
run `make launcher-env`, then select `DOTFILES_LAUNCHER=$HOME/.local/bin/dev` and
`DOTFILES_LAUNCHER_PYTHON=$HOME/.local/share/dotfiles/launcher/bin/python` explicitly.
The wrapper's source determines activation and `dev test` defaults; `DOTFILES_SOURCE`
can override them. Existing activation links must be reconciled when changing source.
Container recreation can lose home state and ends running processes; persistence
across recreation is separate from reconnection to a running tmux server.

## Use the launcher

```sh
dev                              # enter or reconnect in the current environment
dev env                          # inspect environment, workspace and directory
dev --workspace ~/code/project env
dev env enter container          # explicit local entry inside the Feature image
dev exec python -m pytest         # run a project's command with its PATH
dev exec -- printf '%s\n' 'a value with spaces'
```

Each Git worktree is a distinct workspace. Outside Git, discovery uses the current
directory. Explicit paths override discovery. New commands keep the invocation
directory when inside the workspace, otherwise they use its root. `dev env`
reports that directory, not each existing pane's directory.

Tmux owns persistent sessions on the dedicated `dotfiles-dev` server. Detach with
the active prefix followed by `d`, then run `dev` to reconnect without replacing
processes or resetting directories. Entry requires a terminal. The activated
configuration uses Ctrl+A as its prefix; existing user configuration may differ.

`dev exec` preserves arguments, streams, terminal behavior, signals, and exit
status. Local host and local container contexts are supported. Requests to enter
a different environment or rebuild fail explicitly. The launcher requires no
Docker socket; host-managed container creation is future work.

A bind-mounted linked worktree can have unreachable host Git metadata. Discovery
retains its workspace boundary and reports the limitation. Git operations still
need reachable metadata; an explicit workspace path does not repair it.

## Inspect and edit Python

```sh
dev languages src/example.py
dev languages src/example.py --json
nvim src/example.py
dev exec ruff check src/example.py
dev exec pyright src/example.py
```

Inspection reports terminal executables and versions, normal Neovim/ALE startup
selections, interpreter, working directories, and native checker reports. Use
`:DevLanguages` to inspect the current editor buffer, including unsaved changes.
The CLI opens the file on disk in a fresh editor process. Neither path executes
the Python program or formats it. Missing/disabled selections and unresolved
provenance remain visible; OpenCode's configured LSP is not proof of its running
selection or parity with the editor.

Use `gd` for definition, `K` for hover, `Ctrl-X Ctrl-O` for completion, `[d`/`]d`
for diagnostics, and `<leader>pf` for explicit formatting. See [Python](docs/python.md)
for independent interpreter/checker/policy selection and the ALE/Pyright bridge.
See [Neovim](docs/neovim.md), [shells](docs/shells.md), and [tmux](docs/tmux.md)
for editing, completion, logical paths, and clipboard behavior.

**Ctrl-a g** prompts for space-separated window indexes to move into a new tmux
session. Running pane processes survive; moving every window transfers the
workspace identity so a fresh `dev` reconnects to the new session.

## Repository checks

Inside the development container, run these from any directory:

```sh
dev test -q --opencode
dev test tests/test_launcher.py -k reconnect
```

`dev test` runs the repository's pytest suite, forwards its arguments, and returns
its status. The runner checks all locked dependency versions and reports missing
or mismatched environments without installing them. `DOTFILES_TEST_PYTHON` selects
another explicitly provisioned test interpreter. `make test PYTEST_ARGS=-q` uses
the same runner; `make lint` checks shell syntax, ShellCheck, and Python with Ruff.
Run Make targets from the checkout. The Feature's `dev test` runs the installed
snapshot; rebuild after source changes to verify the new package.

Core checks use isolated homes, workspaces, terminal input, and private tmux
servers. They cover activation, shell completion, logical pane paths, tmux keys
and moves, real editor navigation/completion/diagnostics/formatting, effective
inspection, and fresh-process reconnection. The full suite requires the Feature's
toolset. OpenCode's config, state paths, and PR skill discovery have a separate
credential-free opt-in check:

```sh
dev test --opencode -k opencode_config_and_pr_skill -q
```

The base image digest, plugin revisions, personal tool archives, npm dependencies,
and Python package versions are recorded. Apt packages remain build-time
selections, and the Python locks do not verify artifact hashes. See the
[baseline evidence](docs/milestone-1.md) for source-PR accounting and verification
boundaries, including the outstanding manual host-clipboard check.

## Managing Git submodules

Run these commands from the repository root. The parent repository records an
exact commit for each submodule; `.gitmodules` lists their paths and clone URLs.
For a reproducible setup, check out those recorded commits rather than pulling
the latest version inside each plugin.

### Initialize or restore the recorded versions

After cloning, pulling changes to the parent repository, or switching branches:

```bash
git submodule sync --recursive
git submodule update --init --recursive --checkout
git submodule status --recursive
git status
```

* `sync` refreshes local submodule URLs from `.gitmodules`. Existing clones need
  this to pick up URL changes, including the switch from `git://` to HTTPS.
* `--init` initializes missing submodules, and `--recursive` includes nested ones.
* `--checkout` checks out the commit recorded in the parent's index, overriding
  any locally configured merge/rebase update strategy. Detached HEADs inside
  submodules are normal for this workflow.

In `git submodule status`, a leading space means the checkout matches the index,
`-` means uninitialized, and `+` means a different commit is checked out. `U`
means there is a submodule merge conflict to resolve.

### Why status says `(new commits)`

This means the submodule's HEAD differs from the commit recorded by the parent.
It can be an older commit or a different history, not necessarily a newer one.
Running `git pull` inside a plugin, using `submodule update --remote`, or an
automatic updater can cause this. Fetching alone does not change the checkout.

Inspect the difference before choosing whether to restore it or keep it:

```bash
git diff --submodule=log
git diff --cached --submodule=log
git submodule foreach --recursive 'git status --short'
```

To discard an unintended version change, run the restore workflow above.
If you already staged that plugin with `git add`, first unstage its pointer
(replace the example path with the affected submodule):

```bash
git restore --staged vim/bundle/airline
```

An update uses the **index**, so it will otherwise keep the staged version
instead of restoring the commit in the parent's HEAD. If you made local commits
inside a submodule that you want to preserve, create a branch there before
restoring, for example `git -C vim/bundle/airline branch backup/before-update`.

### When an update fails or status is still dirty

If Git says local changes would be overwritten, inspect and save changes
**inside the affected submodule** before retrying:

```bash
git -C vim/bundle/airline status
git -C vim/bundle/airline stash push -u -m "before submodule update"
# Retry the restore workflow above.
```

The parent's stash does not save edits inside submodules. Restore the saved
edits when needed with `git -C vim/bundle/airline stash pop`; doing so makes that
submodule dirty again and may require resolving conflicts at the new version.
Avoid `--force` when you want to preserve local edits.

Submodule updates do not remove modified or untracked files. Check both parent
and submodule status: an untracked plugin directory such as
`vim/bundle/typst.vim/` is not managed by this repository's recorded submodules,
so updating them cannot make that entry disappear. Keep it outside the checkout
or deliberately add it as a submodule if it should be shared.

For network failures, run `git submodule sync --recursive` and check the URL
named in the error. If Git reports that a recorded commit is unavailable,
confirm the remote URL and that the commit still exists upstream; switching to
`--remote` selects a different version rather than repairing the missing pin.

### Intentionally upgrade a plugin

Use `--remote` only when you want to change the version recorded by this
repository. For example:

```bash
git submodule update --init --remote --checkout zsh/plugins/zsh-autosuggestions
git diff --submodule=log -- zsh/plugins/zsh-autosuggestions
# Try the updated plugin, then record its new commit in the parent repository.
git add zsh/plugins/zsh-autosuggestions
git diff --cached --submodule=log -- zsh/plugins/zsh-autosuggestions
git commit -m "Update zsh-autosuggestions submodule"
```

`--remote` follows the configured submodule branch, or the remote's default
branch if none is configured. Until the parent records the new pointer, status
will show a change. For your own plugin commits, push them to an accessible
submodule remote before sharing the parent commit so others can fetch them.

## Ghostty

Activation links `ghostty/` to `$XDG_CONFIG_HOME/ghostty`, defaulting to
`~/.config/ghostty`. The tracked `config.ghostty` sets a green-gray background,
`#1b2920`, so you can visibly confirm that the shared configuration is loaded.
Ghostty 1.2.3 and newer
support this filename; older versions use `config`.

On macOS, Ghostty also loads configuration from
`~/Library/Application Support/com.mitchellh.ghostty/` after the XDG location.
Conflicting settings there override the shared configuration. Consolidate any
existing settings into the tracked file if you want a single configuration.
Activation preserves conflicting files and links and reports them for resolution.

After activation or edits, reload Ghostty with **Cmd+Shift+,** on macOS or
**Ctrl+Shift+,** on Linux to see the background change.

## OpenCode

Activation links `opencode.jsonc` and `skills/` individually into the user-owned
`$XDG_CONFIG_HOME/opencode` directory. OpenCode's generated `package.json`, lockfiles,
and `node_modules/` stay outside the repository. Existing whole-directory links
need the explicit migration described in [activation](docs/activation.md).

The Feature installs OpenCode separately from the launcher runtime. Credentials and session
state belong to the user, outside `~/.config/opencode`. Restart OpenCode after
changing global config or skills.

### GitHub pull request workflow

The [github-pr skill](opencode/skills/github-pr/SKILL.md) uses the GitHub CLI for
PR inspection, full-diff review, checks, and requested mutations. Install `gh`
explicitly, then authenticate in the environment where OpenCode runs:

```sh
gh auth login --hostname github.com --web
gh auth status
```

Restart OpenCode after activation or a skill change so it loads the new skill.
Reviewing a PR does not itself authorize committing, pushing, merging, or closing
it. Shared project CI and integration policy still apply.

## Next integrations

The [roadmap](docs/project.md) builds on this baseline with executable learning
material, source-linked Python experiments, and continuous review. Native macOS
distribution, managed container rebuilds, persistent state across recreation,
and isolated agent execution remain supporting work.
