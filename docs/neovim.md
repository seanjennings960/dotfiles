# Neovim baseline

Milestone 1 step 5 uses the harness's pinned Neovim **0.12.5**. Start directly
from a checkout, including one that has not been installed:

```sh
git submodule update --init --recursive --checkout
nvim -u "$PWD/nvim/init.lua" some-file.md
```

If locally recorded submodule URLs still use `git://`, use a command-local
rewrite: `git -c url.https://github.com/.insteadOf=git://github.com/ submodule
update --init --recursive --checkout`. This fetches the recorded commits.
Startup itself never downloads or updates anything. Missing required plugin
files produce an error with the initialization command.

The activation step links the **entire** repository `nvim` directory to
`${XDG_CONFIG_HOME:-$HOME/.config}/nvim`. `init.lua` resolves its real location,
adds that config directory and its `after` directory to runtimepath, and loads
the selected plugins from the adjacent `vim/bundle` directories. This works for
both the directory symlink and explicit `-u` startup.

## Familiar editing

Four-space expanded tabs are the default. YAML and Markdown use two spaces;
native EditorConfig runs afterward and can override them. Search is incremental,
highlighted, case-insensitive unless the pattern contains capitals. Substitution
is global on each line by default (`gdefault`). Line numbers, an 81st-column
guide, no wrapping, mouse support, and hard-contrast dark Gruvbox are enabled.

| Key / command | Action |
| --- | --- |
| `,i` | Toggle visible whitespace |
| `,N` | Toggle line numbers in this window |
| `,n` | Toggle NERDTree |
| `Ctrl-P` | CtrlP file finder |
| `F4` | Toggle Gruvbox search highlighting (normal/insert/visual) |
| `Enter` in normal mode | Hide search highlighting and move down |
| `/`, `?`, `*` | Re-enable highlighting and search |
| `:StripWhitespace` | Explicit trailing-whitespace cleanup |
| `u`, `Ctrl-R`, `g-`, `g+` | Native undo/redo and undo-history navigation |
| `:ALEInfo` | Inspect ALE and available language tools |

Airline uses text separators without requiring Powerline Python bindings or a
patched font. better-whitespace uses its supported syntax mode, avoiding stale
match IDs in its old pin. Rust, Typst and the existing Python indentation plugin
remain on runtimepath. ALE is loaded; project-aware Python backend configuration
arrives in sibling step 6 through `after/ftplugin/python.lua` and its Lua module.
The core automatically discovers that file when combined. Native LSP/backend
migration comes after the Python ALE baseline is stable.

Gundo's pin remains recorded but is not loaded: it needs a compatible Python
provider. `,u` is deliberately unassigned until an undo-browser trial is enabled.
[Undotree is the recommended trial](neovim-plugins.md). The unused Packer
placeholder is removed. Legacy Python 2/3.5 Powerline paths, unused YCM settings,
`t_Co`, and obsolete `pastetoggle` are absent from the active Lua config. Modern
terminal bracketed paste handles multiline paste.

## State and local experiments

Undo, swap and backup files go in writable, private directories:

```text
${XDG_STATE_HOME:-$HOME/.local/state}/nvim/undo
${XDG_STATE_HOME:-$HOME/.local/state}/nvim/swap
${XDG_STATE_HOME:-$HOME/.local/state}/nvim/backup
```

Full-path filenames prevent collisions between same-named files in different
projects. Persistent undo works across editor processes. Retaining this state
through container recreation is milestone 2 work. Native Neovim data/cache and
CtrlP's XDG cache remain outside the checkout.

The optional `${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/nvim-local.lua` is run
with `dofile` after core setup. It is outside the linked directory; errors are
visible. Add one trial there at a time using [the plugin guide](neovim-plugins.md).
Restart to remove runtime effects after disabling a trial.

## Clipboard and manual terminal checks

Linux without a GUI display, and SSH sessions, use a native OSC52 **copy-only**
provider. Yank to the system clipboard with `"+y` (ordinary yanks also use it).
Paste using the terminal's normal paste shortcut/bracketed paste. The provider
does not query the terminal clipboard; `"+p` uses the editor's unnamed register,
not a clipboard read from Ghostty. On a local graphical desktop Neovim selects
its usual clipboard provider; inspect `:checkhealth vim.provider`.

Automated tests establish startup and editing behavior, not desktop rendering.
On the actual terminal, also check:

- Gruvbox contrast, the column guide, trailing whitespace and line numbers.
- NERDTree, CtrlP and Airline in splits and at narrow window widths; no missing
  separator glyphs.
- `F4` and Enter search highlighting; mouse clicks and terminal bracketed paste.
- Yank a unique string in Neovim and paste it into a desktop app. Repeat through
  the real SSH/tmux path to check OSC52 forwarding. Paste multiline text from
  the desktop into insert mode and check that it is not reindented unexpectedly.
- Save, quit, reopen, then undo; inspect `:set undodir? directory? backupdir?`.

## Automated verification

From the repository root, with initialized pinned submodules:

```sh
docker run --rm --platform linux/arm64 --user vscode \
  -v "$PWD:/workspace" -w /workspace dotfiles-m1:baseline make test
```

`tests/test_neovim.py` uses isolated HOME/XDG directories, actual headless
startup, plugin commands, effective mappings, filetype defaults and EditorConfig
indentation behavior. A pexpect terminal inserts and saves a file, then a second
editor process undoes that saved edit. Tests also cover directory-symlink
activation, local-hook errors and actionable missing-plugin errors.
