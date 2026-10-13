# Learn plugins one at a time

The default remains pinned Gruvbox, NERDTree, CtrlP, Airline/themes,
better-whitespace, ALE and compatible language support. These trials are opt-in;
none are automatically installed or enabled. Native LSP, completion and Python
backend replacement wait until the project-aware ALE Python baseline is stable.

## Trial installation and rollback

Choose **one** section below. Read its upstream README/release notes, select a
release or full commit compatible with Neovim 0.12.5, and install that exact
revision as a native **optional** package outside the checkout. Example for
Undotree (replace `CHOSEN_COMMIT` before running):

```sh
trial="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/pack/trials/opt"
mkdir -p "$trial"
git clone https://github.com/mbbill/undotree.git "$trial/undotree"
git -C "$trial/undotree" checkout --detach CHOSEN_COMMIT
git -C "$trial/undotree" rev-parse HEAD
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
```

Record that full SHA, the Neovim version, and exercise notes in a local trial
log. Cloning happens only when you decide to install. Repeat this pattern with
the repository/package name in the chosen section; pin dependencies too. Do
not move them into `start`, add all six, run startup installers, or update pins
automatically. The snippets below belong in
`${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/nvim-local.lua`.

After installation, generate help tags explicitly in Neovim:
`:helptags <full-path-to-package>/doc`. Run health checks where available.
Compatibility requirements below were checked against upstream READMEs; verify
them again for the actual revision you choose. These are trial recipes, not
claims that each candidate has passed the baseline's automated suite.

**Common rollback:** remove the chosen snippet from the local hook and restart
Neovim. Optional packages do not load without `packadd`. For a completely clean
baseline, rename the hook to `nvim-local.lua.disabled` and restart. You may keep
the pinned optional clone for comparison or remove only that trial's directory.
Existing tracked plugin pins are retained throughout.

## 1. Undotree — undo branches without a Python provider

[mbbill/undotree](https://github.com/mbbill/undotree), optional package `undotree`.
Pure Vimscript; no Python provider. The diff pane uses the external `diff`
executable (`diffutils` in the baseline). Replaces Gundo's UI, not native undo.

```lua
vim.cmd('packadd undotree')
vim.keymap.set('n', '<leader>u', '<Cmd>UndotreeToggle<CR>', { desc = 'Undo tree' })
```

Exercise: in a scratch file, make edit A, then B, undo B, and make C. Open `,u`,
press `?`, and navigate both branches. Save/quit/reopen and inspect the retained
tree. Rollback removes the snippet/mapping on restart; `u` and `g-` keep working,
and the state directory/history stays intact.

## 2. Oil — editable directory buffers

[stevearc/oil.nvim](https://github.com/stevearc/oil.nvim), package `oil.nvim`.
Current upstream requires Neovim 0.10+; icons are optional. This trial uses no
icon provider and leaves NERDTree's `,n` available for comparison.

```lua
vim.cmd('packadd oil.nvim')
require('oil').setup({ default_file_explorer = false, columns = {} })
vim.keymap.set('n', '-', '<Cmd>Oil<CR>', { desc = 'Edit parent directory' })
```

Exercise: create a disposable directory with two files, open one, press `-`,
then `g?`. Rename one entry with normal buffer editing, `:w`, and inspect the
action confirmation and filesystem result. Try `<CR>` and `-` navigation. Oil
is a single-directory buffer, not a persistent tree sidebar. Rollback removes
the snippet and restarts; NERDTree is still the baseline. Reverse any file
renames as filesystem operations—disabling a plugin does not undo saved renames.

## 3. Telescope — file and text search

[nvim-telescope/telescope.nvim](https://github.com/nvim-telescope/telescope.nvim),
package `telescope.nvim`, plus **required**
[nvim-lua/plenary.nvim](https://github.com/nvim-lua/plenary.nvim), package
`plenary.nvim`. Install and pin both individually. Current upstream requires
Neovim >=0.11.7 built with LuaJIT; pinned 0.12.5 meets the version requirement
(check `:version` for LuaJIT). `rg` is required for `live_grep` and included in
the harness. `fd`, icon providers and compiled native sorters are optional and
are not needed for this first trial. Use a release whose documented requirements
match your Neovim rather than blindly adopting a future HEAD.

```lua
vim.cmd('packadd plenary.nvim')
vim.cmd('packadd telescope.nvim')
require('telescope').setup({})
local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Trial find files' })
vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Trial live grep' })
```

Exercise: run `:checkhealth telescope`, find a nested file with `,ff`, inspect the
preview, use `<C-v>` to open a split, then `,fg` to find a known string in the
project. Compare ignored files, speed and ergonomics with CtrlP. Keep `Ctrl-P`
unchanged until deciding to adopt; adoption can remap it to `builtin.find_files`
in the local hook. Rollback removes both packadd/setup lines and trial mappings,
then restarts; baseline CtrlP returns after any local remapping.

## 4. mini.statusline — a text-only Airline alternative

[nvim-mini/mini.statusline](https://github.com/nvim-mini/mini.statusline), package
`mini.statusline`. Use the standalone repo, choosing a commit from its `stable`
branch if desired. Icons and Git integration modules are optional; none are
required for this text-only trial. Read the selected release's Neovim support
policy (the pinned 0.12.5 baseline is suitable for current releases).

```lua
-- The hook runs before startup plugin sourcing; this skips Airline's loader.
vim.g.loaded_airline = 1
vim.cmd('packadd mini.statusline')
require('mini.statusline').setup({ use_icons = false })
```

Exercise: inspect mode, filename, modified marker, cursor position and filetype
while editing in multiple/narrow splits. Compare readability with text-only
Airline. Rollback removes the entire snippet and restarts; Airline loads again.

## 5. Gitsigns — inspect Git hunks

[lewis6991/gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim), package
`gitsigns.nvim`. Current upstream requires Neovim >=0.11.0 and a recent Git;
no Plenary or Python dependency. Use a disposable Git repository for exercises.

```lua
vim.cmd('packadd gitsigns.nvim')
require('gitsigns').setup({})
vim.keymap.set('n', '<leader>hp', '<Cmd>Gitsigns preview_hunk<CR>', { desc = 'Preview hunk' })
```

Exercise: edit a tracked file to create two hunks, save, run
`:Gitsigns nav_hunk next`, and preview with `,hp`. Try `:Gitsigns stage_hunk`,
then inspect `git diff --cached`; unstage with `git restore --staged <file>`.
Compare signs against `git diff`. Rollback removes the snippet and restarts;
Git index changes persist until explicitly unstaged.

## 6. Which-key — discover existing mappings

[folke/which-key.nvim](https://github.com/folke/which-key.nvim), package
`which-key.nvim`. Current upstream requires Neovim >=0.9.4. Icon plugins and a
Nerd Font are optional; core mappings already have `desc` labels.

```lua
vim.cmd('packadd which-key.nvim')
require('which-key').setup({
  icons = { mappings = false, keys = {} },
  triggers = { { '<leader>', mode = { 'n', 'v' } } },
})
```

Exercise: run `:checkhealth which-key`, press comma and pause, discover `i`, `N`
and `n`, execute one, then reopen and cancel with Escape. Compare discoverability
with `:map ,`. Rollback removes the snippet and restarts; core mappings remain.

## Adoption decision

For each trial record: the exact SHAs, dependency versions, which exercise
worked, an ergonomic improvement, a drawback, and whether to keep it. Promote
only a demonstrated improvement in a later focused change. Do not introduce a
second Python diagnostic/completion stack while trying UI/navigation plugins.
