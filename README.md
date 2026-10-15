# Devchain -- Custom Terminal Interface

`dev` is a tmux-based CLI designed to operate as a common operating environment
between human and llm-based agents.

See the [roadmap](docs/project.md) and [architecture](docs/architecture.md) for
the terminal-first environment. The Python `dev` launcher and initial
[personal devtools Feature](features/README.md) are available for local container
development.

## Installation

The current installation workflow assumes `git`, `curl`, and `zsh`. In a `zsh`
shell, run:

```zsh
git clone https://github.com/seanjennings960/dotfiles
cd dotfiles
source ./activate.sh
dev --version
```

Tested natively on MacOS, and also an Ubuntu container (TODO: add link to
CI here).

A more robust installation mechanism is planned. (Although, I guess the
current setup is not too far off the `curl` oneliner which is so common
between modern-day installations. I guess a platform-aware Bash script
is about as universal as it gets. TODO: productionize installation)

## Enter Dev

After installation, change the working directory to a `git` repository and type
```zsh
dev
```
to enter a containerized development environment. `dev` will discover `$ROOT_DIR`, the root of the repository.
Only the code inside `$ROOT_DIR` can be modified without rebuilding the environment.

Call
```zsh
dev --workspace=$PATH_TO_WORKSPACE
```
to bypass workspace discovery.


## Offline-first Environments

An environment contains all the dependencies required to build and run a (multi-lingual)
software package. While environment creation
```zsh
dev env create
```
may require internet connection, they can be rebuilt without connectivity via
```zsh
dev env rebuild
```
.

Each environment is isolated from the next. Filesystem writes do not collide with other environments.

Under the hood, environments correspond to docker images. One image may have many (copied) environments,
to keep environment creation cheap. For now, each environment corresponds to exactly one docker container
(or the host computer).

We also use git worktrees under the hood.

## Running tests

After sourcing `activate.sh`, run the tests from the repository root:

```sh
python -m pytest
```

The activation tests require Bash and Zsh. Pytest skips tests for shells that
are not installed.

TODO: Make a `dev test` command which aliases to `python -m pytest` for now. We'll
do automatic test discovery later







# Legacy Dotfiles

This is what I used to do pre-Docker. Now, everything is handled automatically.
TODO: Prune unused configuration files.

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

OpenCode stores its executable under `~/.opencode` and credentials and session
state outside `~/.config/opencode`. Those locations are not managed by this
repository. Restart OpenCode after changing global config or skills.

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

This repository owns its Ubuntu 24.04 image and project toolchain, including
Python and ShellCheck, in `.devcontainer/Dockerfile`. Its reusable
[devtools Feature](features/README.md) supplies `dev`, Git, Vim, tmux, and Zsh.
The Feature installs the launcher into a private Python environment, separate
from any project virtual environment. Both layers form one devcontainer image.

The container uses the non-root `vscode` user with sudo access and Bash as the
default VS Code terminal. Dotfile configuration activation remains manual.

1. Install and start Docker (Docker Desktop on macOS or Windows).
2. Install host Python 3 for local Feature preparation, then VS Code and the
   **Dev Containers** extension (`ms-vscode-remote.remote-containers`).
3. Open this repository in VS Code, then run **Dev Containers: Reopen in
   Container** from the command palette. The first launch builds the image.

Alternatively, with the Dev Containers CLI installed, run from the repository
root:

```bash
devcontainer up --workspace-folder .
devcontainer exec --workspace-folder . dev env
devcontainer exec --workspace-folder . dev
```

The initialize hook stages the Feature from this checkout before startup.
`dev env` reports container context; `dev exec <command>` preserves the project
directory, executable selection, streams, and exit status. Inside the container,
bare `dev` reconnects to local tmux work. Creating or rebuilding containers through
`dev` is still pending; use the Dev Container CLI for those operations.

Run launcher checks in the installed container:

```sh
devcontainer exec --workspace-folder . dev exec /opt/dotfiles-dev/venv/bin/python -B -m unittest discover -s tests -v
devcontainer exec --workspace-folder . dev exec /opt/dotfiles-dev/venv/bin/python -B tests/container_smoke.py
```

The repository is mounted into the container, so workspace edits persist on the
host. Changes elsewhere in the container, including manually installed packages
and home-directory configuration, can be lost when it is rebuilt.

To add persistent system tools, edit `.devcontainer/Dockerfile`. After changing
the Dockerfile or `.devcontainer/devcontainer.json`, run **Dev Containers:
Rebuild Container** from the VS Code command palette.

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
