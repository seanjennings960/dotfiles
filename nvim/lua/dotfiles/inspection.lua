-- Query ALE and Neovim's native results; do not implement another resolver.
local M = {}

local function tool(executable, enabled, cwd, options)
  local path = vim.fn.exepath(executable)
  return {
    selected = executable,
    path = path ~= '' and path or vim.NIL,
    enabled = enabled,
    status = not enabled and 'disabled' or (path == '' and 'unavailable' or 'resolved'),
    cwd = cwd,
    options = options or '',
  }
end

function M.collect()
  assert(vim.g.dotfiles_initialized == 1, 'Dotfiles Neovim startup did not complete')
  assert(vim.bo.filetype == 'python', 'Inspection currently supports Python buffers')
  local buffer = vim.api.nvim_get_current_buf()
  local setting = vim.fn['ale#Var'](buffer, 'enabled')
  local enabled = setting ~= 0 and setting ~= false
  local selected = vim.fn['ale#linter#Get']('python')
  local function active(name)
    for _, linter in ipairs(selected) do
      if enabled and linter.name == name then return true end
    end
    return false
  end
  local function cwd(value)
    if value == '%s:h' then return vim.fs.dirname(vim.api.nvim_buf_get_name(buffer)) end
    return value ~= vim.NIL and value ~= '' and value or vim.fn.getcwd()
  end
  local fixers = vim.fn['ale#Var'](buffer, 'fixers')
  if not vim.islist(fixers) then fixers = fixers.python or {} end
  local config = vim.fn['ale_linters#python#pyright#GetConfig'](buffer)
  local pyright_cwd = cwd(vim.fn['ale_linters#python#pyright#GetCwd'](buffer))
  local pyright = tool(vim.fn['ale_linters#python#pyright#GetExecutable'](buffer),
    active('pyright'), pyright_cwd)
  pyright.settings = config
  pyright.command = vim.fn['ale_linters#python#pyright#GetCommand'](buffer)
  pyright.connection = 'unresolved'
  pyright.settings_sources = 'unresolved: Pyright does not expose loaded config files through LSP'
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = buffer })) do
    if client.name == pyright.selected .. ':' .. pyright_cwd then
      pyright.connection = client.initialized and 'initialized' or 'starting'
      pyright.settings = client.settings
      pyright.server_info = client.server_info or vim.NIL
      pyright.client_command = client.config.cmd
    end
  end
  return {
    file = vim.api.nvim_buf_get_name(buffer),
    modified = vim.bo.modified,
    cwd = vim.fn.getcwd(),
    config_root = vim.g.dotfiles_config_root,
    startup = vim.env.MYVIMRC,
    scripts = vim.fn.execute('scriptnames'),
    editorconfig = vim.b.editorconfig or vim.NIL,
    indent = { expandtab = vim.bo.expandtab, shiftwidth = vim.bo.shiftwidth },
    interpreter = config.python and config.python.pythonPath or vim.NIL,
    interpreter_source = 'ALE GetConfig / native Pyright client settings; null means unresolved',
    ruff = tool(vim.fn['ale_linters#python#ruff#GetExecutable'](buffer), active('ruff'),
      cwd(vim.fn['ale_linters#python#ruff#GetCwd'](buffer)),
      vim.fn['ale#Var'](buffer, 'python_ruff_options')),
    formatter = tool(vim.fn['ale#fixers#ruff_format#GetExecutable'](buffer),
      vim.tbl_contains(fixers, 'ruff_format'),
      cwd(vim.fn['ale#fixers#ruff_format#GetCwd'](buffer)),
      vim.fn['ale#Var'](buffer, 'python_ruff_format_options')),
    pyright = pyright,
    history = vim.fn['ale#history#Get'](buffer),
    ale_info = vim.fn.execute('ALEInfo -echo'),
    messages = vim.fn.execute('messages'),
  }
end

function M.write()
  local ok, result = xpcall(function()
    assert(vim.g.dotfiles_initialized == 1, 'Dotfiles Neovim startup did not complete')
    vim.cmd('ALELint')
    local ready = vim.wait(8000, function()
      local snapshot = M.collect()
      return vim.fn['ale#engine#IsCheckingBuffer'](vim.api.nvim_get_current_buf()) == 0
        and (snapshot.pyright.status ~= 'resolved' or snapshot.pyright.connection == 'initialized')
    end, 50)
    local snapshot = M.collect()
    snapshot.settled = ready
    return snapshot
  end, debug.traceback)
  vim.fn.writefile({ vim.json.encode(ok and result or { error = result }) }, vim.env.DEV_INSPECTION_RESULT)
  vim.cmd('qa!')
end

function M.show()
  local report = M.collect()
  vim.cmd('botright new')
  vim.bo.buftype, vim.bo.bufhidden, vim.bo.swapfile = 'nofile', 'wipe', false
  vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(vim.inspect(report), '\n'))
  vim.bo.modifiable = false
end

return M
