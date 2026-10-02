# Bash and Zsh startup (milestone 1, step 3)

Bash remains the default shell. Both configurations support the same path and
Git completion exercises and the pane-local tmux directory contract. A preference
decision requires the manual evaluation below; the automated tests establish
behavior, not which shell feels better.

## Sourcing and activation integration

`bashrc` and `zshrc` are **personal interactive snippets**, not replacements for
system or user startup files. Activation should link `bashrc`, `bash_aliases`,
and `zshrc` into the user-owned `${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/`.
The managed block in `~/.bashrc` should source:

```sh
if [ -r "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/bashrc" ]; then
    . "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/bashrc"
fi
```

Bash login startup should source `~/.bashrc` from the user's selected profile
(`~/.bash_profile`, `~/.bash_login`, or `~/.profile`, following Bash's precedence).
Activation owns these managed blocks and must preserve surrounding user content.
Zsh's managed block belongs in `${ZDOTDIR:-$HOME}/.zshrc` and sources the linked
`dotfiles/zshrc` in the same way. Zsh reads `.zshrc` for both interactive login
and nonlogin shells. Neither snippet modifies noninteractive startup.

Direct evaluation also works:

```sh
source /path/to/checkout/bashrc   # in interactive Bash
source /path/to/checkout/zshrc    # in interactive Zsh
```

Bash uses Linux `realpath` (falling back to `readlink -f`) on `BASH_SOURCE[0]`;
Zsh uses its `:A:h` path modifiers on the sourced filename. Thus the aliases come
from the actual checkout even through XDG links; no `~/dotfiles` assumption is
needed. This Bash resolution targets the milestone's Linux environment.

Repeated sourcing keeps one `~/bin` entry, one Zsh directory-change hook, and one
completion/local-settings initialization. `~/bin` is appended so existing
project/venv executables retain precedence. `vim` is simply an alias for `nvim`;
Neovim uses its native XDG configuration and state paths. Missing Neovim or tmux
does not cause startup output. Invoking `vim` still requires Neovim to be installed.

## Machine-local settings

Create `dotfiles/local.bash` or `dotfiles/local.zsh` in your XDG config directory.
These optional files are sourced once per interactive shell and are user-owned.
Use them for machine-specific Android SDK variables, ROS setup, prompt preferences,
or other personal settings. Keep them quiet and make any PATH additions idempotent.
For example, in either local file:

```sh
export ANDROID_HOME="$HOME/Android/Sdk"  # choose this machine's real SDK path
if [ -d "$ANDROID_HOME/platform-tools" ]; then
    case :$PATH: in
        *:"$ANDROID_HOME/platform-tools":*) ;;
        *) export PATH="$PATH:$ANDROID_HOME/platform-tools" ;;
    esac
fi
# Source a ROS setup file here only when installed, using its actual local path.
```

## Completion and optional Zsh framework

Bash uses installed `bash-completion`, including its lazy Git completion loader.
On Ubuntu install `bash-completion` and Git before evaluation. Zsh uses the
installed shell's `compinit` and Git completion with Tab explicitly bound to
`expand-or-complete`. Its completion cache is in the user's home; the directory
must be writable. Shell startup performs no network access or plugin installation.

The framework is optional. Set `DOTFILES_USE_OH_MY_ZSH=1` in `local.zsh` to load
the existing checkout pins if prepared:

- oh-my-zsh: `6e9cda3d30d8e73c11e4d32044b7f4c5e06f822d`
- zsh-autosuggestions: `d6d9a469819c2bddb4d4f1d0d353070af96226e2`

Preparation is an explicit operation outside startup:

```sh
git submodule update --init -- oh-my-zsh zsh/plugins/zsh-autosuggestions
```

`ZSH` points at the real checkout's `oh-my-zsh`; `ZSH_CUSTOM` points at its `zsh`
directory, so the plugin is correctly found under `zsh/plugins/`. Auto-updates
are disabled with both the modern style and the legacy flag for the pinned
version. An absent framework or autosuggestions checkout is quietly skipped.
The baseline automated comparison exercises plain Zsh, not this opt-in framework.

## tmux integration contract (step 4)

After successful directory changes the shell records logical `$PWD` with:

```sh
tmux set-environment -g "TMUX_${TMUX_PANE}_PATH" "$PWD"
```

Both `TMUX` and a `%`-prefixed `TMUX_PANE` must be present, and `tmux` must be
available. The shell uses `TMUX_PANE` directly; it does not query pane IDs or call
tmux outside a session. Bash wraps `builtin cd` in a function; Zsh keeps native
`cd` semantics and uses a deduplicated `chpwd` hook. Failed `cd` preserves the
builtin's failure status and leaves metadata unchanged. A bookkeeping failure
does not change a successful `cd` into failure.

The tmux helper should pass `DOTFILES_START_DIR` to each new pane/window via
`-e`, using the origin pane's metadata. Startup consumes it with
`builtin cd -- "$DOTFILES_START_DIR"`, unsets it, then initializes metadata.
This retains a symlink's logical spelling, including paths containing spaces.
An invalid start directory reports the normal `cd` error, consumes the variable,
and records the actual current directory. There is no shared `NEWW` handshake.
Using `builtin cd` explicitly in Bash after startup bypasses its tracking wrapper;
normal `cd` should be used for changes that tmux needs to inherit.

Step 4 owns its helper, bindings, and tmux config. The shell tests use a private
server with `-f /dev/null`, bypassing this branch's old root tmux configuration.
Combined activation/tmux acceptance is still required after the steps integrate.

## Verified automated comparison

`tests/test_shells.py` uses the shared isolated home/environment, subprocess,
terminal, and private tmux-server fixtures. It checks both shells for:

- Interactive login and nonlogin startup through XDG symlinks.
- Real Tab input for directories and Git files with spaces and Git branches.
- Direct sourcing and noninteractive guards; repeated sourcing and local hooks.
- Venv PATH precedence, a single `~/bin`, quiet missing optional tools.
- Successful/failed `cd` status, logical symlink paths, failed tmux bookkeeping,
  and no further tmux calls after leaving a session environment.
- Real tmux per-pane start-directory handoff and server-global pane metadata.

Run in the baseline Linux ARM64 image:

```sh
docker run --rm --platform linux/arm64 --user vscode \
  -v "$PWD:/workspace" -w /workspace dotfiles-m1:baseline make test
docker run --rm --platform linux/arm64 --user vscode \
  -v "$PWD:/workspace" -w /workspace dotfiles-m1:baseline \
  shellcheck bashrc bash_aliases
```

## Manual comparison checklist

In Ghostty with the integrated activation and tmux steps, run the same exercises
in `bash -i`, `bash -il`, `zsh -i`, and `zsh -il`:

1. Confirm quiet startup outside tmux and correct aliases after activation twice.
2. Tab-complete a directory/file with spaces and a Git branch; compare ambiguous
   candidate display, quoting, and repeated Tab behavior.
3. Navigate through a symlink, split panes/create windows, and confirm `pwd`
   retains the logical spelling. Try a nonexistent directory and inspect `$?`.
4. Activate a project venv, source the snippet twice, and inspect `command -v
   python` and `$PATH`. Confirm the project's executable wins.
5. Compare history recall/search, line editing, prompt rendering, and startup
   responsiveness. Record concrete observations for each shell.
6. Optionally prepare the pinned framework and enable it locally; repeat before
   deciding whether the theme/autosuggestions improve your workflow.
7. Record the user's decision separately. Keep Bash as default until that decision.

Existing draft PR #9 also edits `bash_aliases` to add Julia initialization. Its
hard-coded Zsh-style Julia PATH block is a separate review concern; this step
does not adopt Julia scope. Reconcile that overlap deliberately when integrating
the PRs, preserving the intended Julia work rather than silently dropping it.
