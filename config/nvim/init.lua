vim.g.mapleader = ","

local opt = vim.opt
opt.expandtab = true
opt.tabstop = 4
opt.softtabstop = 4
opt.shiftwidth = 4
opt.shiftround = true
opt.number = true
opt.ignorecase = true
opt.smartcase = true
opt.incsearch = true
opt.hlsearch = true
opt.autoread = true
opt.mouse = "a"

-- Packaged configuration is read-only; keep editing state in the user's state directory.
local state = vim.fn.stdpath("state")
for _, directory in ipairs({ "undo", "swap", "backup" }) do
  vim.fn.mkdir(state .. "/" .. directory, "p")
end
opt.undodir = state .. "/undo//"
opt.directory = state .. "/swap//"
opt.backupdir = state .. "/backup//"
opt.undofile = true
opt.backup = true

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("DevchainIndent", { clear = true }),
  pattern = { "yaml", "markdown" },
  callback = function()
    vim.opt_local.tabstop = 2
    vim.opt_local.softtabstop = 2
    vim.opt_local.shiftwidth = 2
  end,
})
