local opt = vim.opt
opt.wrap = false
opt.tabstop = 4
opt.softtabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.shiftround = true
opt.autoindent = true
opt.copyindent = true
opt.number = true
opt.showmatch = true
opt.ignorecase = true
opt.smartcase = true
opt.smarttab = true
opt.scrolloff = 4
opt.virtualedit = 'all'
opt.hlsearch = true
opt.incsearch = true
opt.gdefault = true
opt.listchars = { tab = '▸ ', trail = '·', extends = '#', nbsp = '·' }
opt.list = false
opt.mouse = 'a'
opt.fileformats = { 'unix', 'dos', 'mac' }
opt.formatoptions:append('1')
opt.nrformats = ''
opt.shortmess:append('I')
opt.autoread = true
opt.laststatus = 2
opt.termguicolors = true
opt.background = 'dark'
opt.colorcolumn = '81'

-- stdpath honors XDG_STATE_HOME; double slash encodes the complete file path.
local state = vim.fn.stdpath('state')
for name, option in pairs({ undo = 'undodir', swap = 'directory', backup = 'backupdir' }) do
  local directory = state .. '/' .. name
  vim.fn.mkdir(directory, 'p', 448) -- 0700
  assert(vim.fn.filewritable(directory) == 2, 'Not writable: ' .. directory)
  opt[option] = directory .. '//'
end
opt.undofile = true
opt.backup = true
opt.writebackup = true
opt.swapfile = true

-- Native EditorConfig runs after filetype defaults and remains authoritative.
vim.g.editorconfig = true

-- Copy over OSC52 in SSH/container terminals; paste uses normal terminal paste.
-- Do not issue clipboard read queries (not supported by every terminal).
if vim.env.SSH_TTY or (vim.fn.has('linux') == 1 and not vim.env.DISPLAY
    and not vim.env.WAYLAND_DISPLAY) then
  local osc52 = require('vim.ui.clipboard.osc52')
  local function local_paste()
    return { vim.fn.getreg('"', 1, true), vim.fn.getregtype('"') }
  end
  vim.g.clipboard = {
    name = 'OSC 52 (copy only)',
    copy = { ['+'] = osc52.copy('+'), ['*'] = osc52.copy('*') },
    paste = {
      ['+'] = local_paste,
      ['*'] = local_paste,
    },
  }
end
opt.clipboard = 'unnamedplus'
