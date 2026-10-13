local M = {}

function M.setup(repo)
  -- Load only the compatible pinned baseline. No install/update at startup.
  local plugins = {
    { 'gruvbox', 'colors/gruvbox.vim' },
    { 'nerdtree', 'plugin/NERD_tree.vim' },
    { 'ctrlp', 'plugin/ctrlp.vim' },
    { 'airline', 'plugin/airline.vim' },
    { 'airline-themes', 'autoload/airline/themes/simple.vim' },
    { 'better-whitespace', 'plugin/better-whitespace.vim' },
    { 'ale', 'plugin/ale.vim' },
    { 'rust', 'ftplugin/rust.vim' },
    { 'vim-python-pep8-indent', 'indent/python.vim' },
    { 'typst.vim', 'ftdetect/typst.vim' },
  }
  for _, plugin in ipairs(plugins) do
    local path = repo .. '/vim/bundle/' .. plugin[1]
    assert(vim.fn.filereadable(path .. '/' .. plugin[2]) == 1,
      'Missing pinned plugin ' .. plugin[1] .. '. In ' .. repo
        .. ' run: git submodule update --init --recursive --checkout')
    vim.opt.runtimepath:append(path)
    if vim.fn.isdirectory(path .. '/after') == 1 then
      vim.opt.runtimepath:append(path .. '/after')
    end
  end
  vim.g.gruvbox_contrast_dark = 'hard'
  vim.g.airline_theme = 'gruvbox'
  vim.g.airline_powerline_fonts = 0 -- works without a patched font
  -- This old pin keeps a global match ID across windows. Its supported syntax
  -- mode avoids invalid matchdelete IDs when opening/closing plugin windows.
  vim.g.current_line_whitespace_disabled_soft = 1
  vim.cmd('colorscheme gruvbox')
  -- Gundo needs a Python provider. Leave it unloaded; trial Undotree instead.
  -- Python ALE/backend policy belongs to the sibling Python integration.
end

return M
