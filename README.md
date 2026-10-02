# Dotfiles

A terminal-first workflow built around Bash, tmux, Neovim, and OpenCode. The
initial tested platform is Ubuntu 24.04 ARM64, with Ghostty on the Mac host.

See the [roadmap](docs/project.md) for the planned terminal-first environment,
Dev Container Feature, and host-side `dev` launcher, and the
[architecture](docs/architecture.md) for how they fit together.

Use the development container below for the supplied toolchain. Activation is
offline and runs as the development user; it requires Bash and Python 3.9+.

To use the dotfiles:
```bash
git clone https://github.com/seanjennings960/dotfiles.git
cd dotfiles
git submodule sync --recursive
git submodule update --init --recursive --checkout
./install.sh
```

Start a fresh shell (`exec bash`) to load the startup configuration before
starting tmux.

Activation links the managed application configuration, installs the tmux helper
in `~/bin`, and adds one source block to Bash/Zsh startup files. Repeated runs
are safe. Personal shell content is preserved; conflicting editor/tmux links are
reported with a nonzero exit status. Plugin preparation is separate from
activation. `infectdots.sh` delegates to the same installer.

See [activation details](docs/activation.md) for XDG overrides, conflict handling,
and the user-owned configuration/state layout.

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

## OpenCode

Activation creates a user-owned `~/.config/opencode` directory and links the
versioned `opencode.jsonc` and skills into it. OpenCode can generate package
manifests, lockfiles, and `node_modules/` there without writing into the checkout.
An existing unmanaged configuration is preserved and reported as a conflict.

The devcontainer installs a pinned OpenCode executable at
`/usr/local/bin/opencode`. Credentials and session state belong to the development
user and are created at runtime, outside `~/.config/opencode`. Restart OpenCode
after changing global config or skills.

## Development container

The devcontainer provides Ubuntu 24.04 with Git, Vim, Bash completion, tmux, Zsh,
ShellCheck, Python 3.12, Neovim 0.12.5, Ruff 0.16.10, Pyright 1.1.414, and
OpenCode 1.18.34. Pyright uses its own Node 22.20.0 runtime, independent of a
project's Node selection. Release archives have recorded SHA-256 checksums;
Pyright's npm dependency graph and Python test dependencies are locked. The base
image is digest-pinned; Ubuntu package updates are resolved at build time.
It uses the non-root `vscode` user with sudo access and Bash as the default
VS Code terminal. Dotfile activation is manual, so you can choose which
configurations to try inside the container.

1. Install and start Docker (Docker Desktop on macOS or Windows).
2. Install VS Code and the **Dev Containers** extension
   (`ms-vscode-remote.remote-containers`).
3. Open this repository in VS Code, then run **Dev Containers: Reopen in
   Container** from the command palette. The first launch builds the image.

Alternatively, with the Dev Containers CLI installed, run from the repository
root:

```bash
devcontainer up --workspace-folder .
devcontainer exec --workspace-folder . bash
```

The repository is mounted into the container, so workspace edits persist on the
host. Changes elsewhere in the container, including manually installed packages
and home-directory configuration, can be lost when it is rebuilt.

To add persistent system tools, edit `.devcontainer/Dockerfile`. After changing
the Dockerfile or `.devcontainer/devcontainer.json`, run **Dev Containers:
Rebuild Container** from the VS Code command palette.

## Tests and milestone 1

The [milestone execution plan](docs/milestone-1.md) separates automated terminal
checks from manual Ghostty, host clipboard, and workflow evaluations.

From the repository root:

```bash
devcontainer up --workspace-folder .
devcontainer exec --workspace-folder . make test
```

The tested CLI version is `@devcontainers/cli` 0.80.1. The baseline is Linux ARM64;
report x86-64 or emulated runs separately. Run tests as the non-root development
user. The image installs the locked test dependencies into
`/opt/dotfiles/test-venv`; `make test` uses that interpreter. For another compatible
Linux environment, install `requirements-dev.lock` into a dedicated virtual
environment and set `TEST_PYTHON` to its Python executable.

Tests use temporary homes, XDG directories, and workspaces, private tmux sockets,
and simulated terminal input. Failed terminal tests include transcripts in pytest
output. Each workflow step supplies its behavioral tests and lint checks; the
combined suite covers activation, shells, tmux, Neovim, and Python selections.
The devcontainer's init process reaps application subprocesses; for direct Docker
test runs, use `docker run --init`.

## Workflow guides

- [Activation](docs/activation.md): startup blocks, conflicts, writable state.
- [Shells](docs/shells.md): completion, local settings, Bash/Zsh comparison.
- [tmux](docs/tmux.md): shortcuts, logical directories, terminal clipboard.
- [Neovim](docs/neovim.md): editing defaults, mappings, EditorConfig, undo state.
- [Python](docs/python.md): Ruff, Pyright, project overrides, tooling inspection.
- [Plugin trials](docs/neovim-plugins.md): learn and evaluate one plugin at a time.

Bash remains the default while Zsh is evaluated. Clipboard copying uses OSC52
through the attached terminal; verify delivery to the Mac clipboard and paste
back through Ghostty using the manual checklist in the milestone plan.
