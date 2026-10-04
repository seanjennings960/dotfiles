# Rahul Rawat's Dotfiles

A collection of the dotfiles used on my work and home Linux machines.

See the [roadmap](docs/project.md) for the planned terminal-first environment,
Dev Container Feature, and the host-side `dev` launcher, and the
[architecture](docs/architecture.md) for how they fit together.

Prerequisites:
```
sudo apt-get install tmux
sudo apt-get install vim
sudo apt-get isntall zsh
```

To use the dotfiles:
```bash
cd
git clone https://github.com/rahulraw/dotfiles.git
cd dotfiles
git submodule update --init --recursive --checkout
./infectdots.sh
```

This install script does the following things: 
* Link .* (dotfiles) on your computer to this directory
* Initialize and update git submodules for pathogen plugins

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

The installer links `ghostty/` to `~/.config/ghostty`. The tracked
`config.ghostty` sets a blue-gray background (`#203040`) so you can visibly
confirm that the shared configuration is loaded. Ghostty 1.2.3 and newer
support this filename; older versions use `config`.

Ghostty reads this location on both macOS and Linux when `XDG_CONFIG_HOME` is
unset or points to `~/.config`. If you use a different `XDG_CONFIG_HOME`, link
`ghostty/` into that directory instead.

On macOS, Ghostty also loads configuration from
`~/Library/Application Support/com.mitchellh.ghostty/` after the XDG location.
Conflicting settings there override the shared configuration. Consolidate any
existing settings into the tracked file if you want a single configuration.
The installer preserves an existing `~/.config/ghostty` rather than replacing
it; move it aside before activation if you want to use the repository link.

After activation or edits, reload Ghostty with **Cmd+Shift+,** on macOS or
**Ctrl+Shift+,** on Linux to see the background change.

## OpenCode

The installer links `opencode/` to `~/.config/opencode`, making its config,
agents, commands, plugins, and skills available to every OpenCode session.
OpenCode writes JavaScript dependency state into this directory at startup;
`package.json`, lockfiles, and `node_modules/` are generated and intentionally
ignored by Git.

OpenCode installation is separate from the launcher. Credentials and session
state belong to the user, outside `~/.config/opencode`. Restart OpenCode after
changing global config or skills.

To install xclip (allows your tmux buffer to sync with the system buffer):
```bash
sudo apt-get install --assume-yes xclip
```

To install YouCompleteMe:
```bash
cd ~/.vim/bundle/YouCompleteMe
./install.py --all
```

## Development container

The devcontainer provides Ubuntu 24.04 with Python 3.12, venv support, Make,
Git, Vim, tmux, Zsh, and ShellCheck.
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

## Development launcher

The Python/Click launcher initially runs in this repository's Ubuntu 24.04
ARM64 devcontainer as non-root `vscode`, using Ubuntu's Python 3.12. Explicit
creation setup provisions a launcher virtualenv in
`~/.local/share/dotfiles/launcher` and a separate locked test environment under
`~/.cache/dotfiles/tests`. Both live inside the container, outside the mounted
checkout. Project virtualenvs and Python import settings do not select the
launcher's runtime. Personal tools and activation follow in later PRs.

```sh
devcontainer up --workspace-folder .
devcontainer exec --workspace-folder . dev env
devcontainer exec --workspace-folder . dev test -q
```

The configured `postCreateCommand` runs `make launcher-env test-env`. This is
explicit environment setup and can download locked dependencies. Entry and
`dev test` never install dependencies. Repeat setup inside the container with
`make launcher-env test-env` after changing the launcher/test locks.
macOS installation, Homebrew packaging, and macOS installer adapters are deferred.

```sh
dev                              # enter or reconnect to human host-mode work
dev env                          # show environment, workspace and initial cwd
dev --workspace ~/code/project env
dev env enter host
dev exec python -m pytest         # run a project's command with its PATH
dev exec -- printf '%s\n' 'a value with spaces'
```

Inside this devcontainer, `host` means the Linux container running the launcher,
not the outer Mac. The launcher does not create managed containers or require a
Docker socket. Use the commands above inside a container terminal for interactive
entry; noninteractive entry reports that a terminal is required.

Each Git worktree is a distinct workspace. Outside Git, the invocation directory
is the workspace. Explicit paths override discovery. Commands keep the invocation
directory when it lies inside the workspace, otherwise they use the root.
If a mounted linked worktree's `.git` file points at inaccessible host metadata,
discovery uses that worktree boundary and inspection reports metadata unavailable.
Git commands still require reachable Git metadata; an explicit workspace path
does not repair it.
Tmux owns persistent sessions on the dedicated `dotfiles-dev` server. Detach with
the active tmux prefix followed by `d`; entry from a fresh launcher reconnects
without changing running panes. Existing user tmux and shell configuration can
still affect interactive startup. Personal activation and bindings follow later.
`dev env` reports the directory new commands use, not each existing pane's cwd.

`dev exec` preserves arguments, stdin/stdout/stderr, terminal, signals and status.
Container entry, container context, and rebuild fail without executing on the host.

## Repository tests

Creation setup provisions the locked test environment. Inside the devcontainer,
run repository checks from any directory:

```sh
dev test -q
dev test tests/test_launcher.py -k reconnect
```

To repeat explicit editable setup from the mounted checkout, inside the container:

```sh
make launcher-env
make test-env
make test PYTEST_ARGS=-q
```

`dev test` runs this repository's pytest suite, forwards runner arguments and
returns its exit status. It requires the locked test environment and reports
missing dependencies without installing. Set `DOTFILES_TEST_PYTHON` to use another
explicitly provisioned interpreter. The default test cache is keyed by the lock.
Launcher integration tests require tmux; they do not require the full personal
toolset or Docker access. Tests invoke the installed production `dev` wrapper,
use isolated homes/workspaces and private tmux sockets, and preserve terminal
transcripts on failures. Python package versions are pinned; the Ubuntu base
tag and apt package resolution remain unpinned inputs.

See [launcher contracts and feature handoff](docs/milestone-1.md) for APIs, test
registration, and manual verification boundaries.

### Known Issues

* Powerline does not always work as intended. Look through the Powerline installation
guide on github

* Powerline will show weird icons by default in the powerline bar. Set the powerline 
mapping to 0 to fix this.

* If there is errors involving a "vim error" due to comments in the vimrc, restarting
your computer can fix the problems. Thanks Linus! 

### Future Improvements
* Transition to Vundle from Pathogen  
Pathogen way to version control utilized git submodules. Vundle requires 
plugin calls in your vimrc files which is a little more elegant.

* Transition to Antigen from Oh-my-zsh   
Antigen is built with inspiration of oh-my-zsh and pathogen. However, it 
is tries to avoid the bloat of oh-my-zsh using Vundle inspired plugin calls.

* Fix autosuggestions bug

* ALE not working in new setups

* Uses Powerline by default
Find way to set powerline setting if available
