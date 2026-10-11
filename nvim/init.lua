-- Resolve the real directory even when this entire config is symlinked.
local source = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fs.dirname(assert(vim.uv.fs_realpath(source)))
vim.g.dotfiles_config_root = root
vim.opt.runtimepath:prepend(root)
vim.opt.runtimepath:append(root .. '/after')
vim.g.mapleader = ','
vim.g.maplocalleader = ','

require('dotfiles.options')
require('dotfiles.plugins').setup(vim.fs.dirname(root))
require('dotfiles.keymaps')
vim.cmd('filetype plugin indent on')
vim.cmd('syntax enable')

-- Trials live outside the linked repository. Errors must remain visible.
local config_home = vim.env.XDG_CONFIG_HOME or (vim.env.HOME .. '/.config')
local local_config = config_home .. '/dotfiles/nvim-local.lua'
if vim.fn.filereadable(local_config) == 1 then
  dofile(local_config)
end
vim.g.dotfiles_initialized = 1
vim.api.nvim_create_user_command('DevLanguages', function()
  require('dotfiles.inspection').show()
end, { desc = 'Inspect the current buffer and its actual ALE selections' })
