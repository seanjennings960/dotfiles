# User activation

From the checkout, run `./install.sh` as your regular user. Python 3.9+ and
standard `ln` are required; the milestone image supplies them. `./infectdots.sh`
is a compatibility entry point for the same operation. Activation is offline:
it does not provision tools, fetch plugins, or initialize/update submodules.

`HOME` must be an existing writable absolute directory. Activation respects
absolute `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_STATE_HOME`, and `XDG_CACHE_HOME`
overrides; unset/empty values use their standard home-relative defaults.

## Links and writable state

- `nvim/` → `$XDG_CONFIG_HOME/nvim` (an uninitialized plugin submodule is fine).
- `tmux.conf` → `$HOME/.tmux.conf`.
- Executable `tmux/tmux_neww.sh` → `$HOME/bin/tmux_neww`.
- `bashrc`, `bash_aliases`, `zshrc` → a user-owned `$XDG_CONFIG_HOME/dotfiles/`.
- `opencode/opencode.jsonc` and `opencode/skills` → individual links inside a
  user-owned `$XDG_CONFIG_HOME/opencode/`. Generated `package.json` and
  `node_modules` stay there and are preserved on repeat activation.

Neovim gets writable undo, swap, and backup directories under
`$XDG_STATE_HOME/nvim/`. Data/cache directories for Neovim and native OpenCode
data/state/cache directories are created outside the repository. Later Neovim
startup configuration must use those paths. The optional personal trial hook is
`$XDG_CONFIG_HOME/dotfiles/nvim-local.lua`; activation never creates or manages it.

## Startup hooks and conflicts

A marked, idempotent source block is installed in `.bashrc`, `.zshrc`, and the
effective Bash login file: first existing `.bash_profile`, `.bash_login`, or
`.profile`, otherwise a new `.profile`. All personal content outside managed
blocks is preserved, as are existing file permissions. Hooks use runtime XDG
fallback and quoted paths, including paths containing spaces or shell metacharacters.
Existing login startup semantics are retained; shell snippets are responsible
for guarding interactive/duplicate initialization.

Correct links (including relative links) are no-ops. Foreign files, directories,
and symlinks, including dangling links, cause a nonzero exit and are preserved.
Startup symlinks/nonregular files, malformed managed blocks, missing sources,
and unwritable destinations also fail preflight before any changes. Resolve
reported conflicts explicitly, then retry. No automatic backup/overwrite policy
is applied. User-owned config directories cannot themselves be symlinks.

If a write/link fails after preflight, activation rolls back its created links,
directories, and startup edits. Run activation without concurrent edits to the
same destinations. Re-running a successful activation leaves correct links and
startup files untouched.

## Verification

The activation integration tests run the real installer as a non-root user in
isolated homes. A credential-free `opencode debug config --pure` smoke resolves
the linked config with model fetching disabled; `opencode debug paths --pure`
checks native XDG paths. This does not exercise provider requests or desktop
integration. Interactive shell behavior, tmux behavior, and Neovim startup are
verified by their subsequent milestone steps.
