# User activation

After [launcher setup](../README.md#set-up-the-host-workflow), run `dev activate`
as the development user. It uses the launcher's isolated Python runtime and the
checkout containing `dotfiles_dev`, independent of the invoking project.
`DOTFILES_SOURCE` explicitly selects another configuration checkout.

`./install.sh` and `./infectdots.sh` call the same command for their own checkout.
They find the wrapper at `~/.local/bin/dev`; `DOTFILES_LAUNCHER` can select another
installed wrapper. A missing launcher fails with setup instructions. Neither
script installs tools, fetches plugins, nor updates submodules.

Start a fresh shell after activation, then enter with `dev`. Activation changes
future startup; it does not reload an existing shell or tmux server.

## Destinations

`HOME` must be an existing writable absolute directory. The `XDG_CONFIG_HOME`,
`XDG_DATA_HOME`, `XDG_STATE_HOME`, and `XDG_CACHE_HOME` overrides must be absolute;
empty or unset values use their standard home-relative defaults.

| Source | Destination |
| --- | --- |
| `nvim/` | `$XDG_CONFIG_HOME/nvim` |
| `ghostty/` | `$XDG_CONFIG_HOME/ghostty` |
| `tmux.conf` | `$HOME/.tmux.conf` |
| `tmux/tmux_neww.sh` | `$HOME/bin/tmux_neww` |
| `bashrc`, `bash_aliases`, `zshrc` | `$XDG_CONFIG_HOME/dotfiles/` |
| `opencode/opencode.jsonc`, `opencode/skills/` | Individual links in `$XDG_CONFIG_HOME/opencode/` |

The destination OpenCode directory belongs to the user. Generated `package.json`,
lockfiles, and `node_modules/` stay there and survive repeat activation. Neovim
undo, swap, and backup directories are prepared under `$XDG_STATE_HOME/nvim`.
Applications must use their external data/state/cache locations. The later
editor PR supplies the normal Neovim startup that consumes these directories.
The optional `$XDG_CONFIG_HOME/dotfiles/nvim-local.lua` remains unmanaged.

## Startup and conflicts

Activation installs a marked source block in `.bashrc`, `.zshrc`, and the first
existing Bash login file in `.bash_profile`, `.bash_login`, `.profile` order. If
none exists, it creates `.profile`. It preserves personal content and permissions
outside the block, and uses quoted runtime HOME/XDG paths.

The baseline makes installed helpers discoverable through `~/bin`. Zsh guards
repeated and noninteractive loading and tolerates missing optional Oh My Zsh and
ROS files. Framework updates are disabled during startup. The shell follow-up
owns completion, aliases, project environment behavior, and pane bookkeeping.

Correct links are no-ops. Foreign files, directories, or links, including dangling
links, are preserved conflicts. Nonregular startup files, malformed blocks,
missing sources, unwritable destinations, and writable state inside the source
checkout fail preflight before mutation. Write failures roll back created links,
directories, and changed startup files. Run activation without concurrent edits
to those destinations.

### Existing whole-directory OpenCode links

Older installations linked `~/.config/opencode` directly into the repository.
Activation reports that as a conflict because OpenCode writes into its config
directory. Inspect the link target and its generated or personal files first.
Then replace the link with a user-owned directory and move any personal/generated
files you want to retain into it. Run activation again to create the individual
config and skill links. Existing personal config or skill directories remain
conflicts to reconcile explicitly; activation never overwrites them.

Quit and restart OpenCode after activation so it discovers the configuration and
skills. Its credentials and session history stay in native user-owned locations.

## Verification

`dev test` exercises real entry points with non-root isolated homes, repeated
activation, preserved bytes and modes, relative and broken links, rollback,
runtime quoting, generated application state, and activated tmux reconnection.
`dev test --opencode -k opencode_config_and_pr_skill` additionally checks the real
OpenCode config, state paths, and GitHub PR skill discovery without credentials.
This optional check fails if requested without an installed OpenCode executable.
