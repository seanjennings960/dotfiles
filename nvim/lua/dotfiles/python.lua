local M = {}
local listening = false

local function warn(message)
  vim.notify('Python tooling: ' .. message .. ' (see :ALEInfo)', vim.log.levels.WARN)
end

function M.inspect()
  local buffer = vim.api.nvim_get_current_buf()
  local enabled = vim.fn['ale#Var'](buffer, 'enabled')
  if enabled == 0 or enabled == false then
    return
  end
  local tools = {
    ruff = vim.fn['ale_linters#python#ruff#GetExecutable'](buffer),
    pyright = vim.fn['ale_linters#python#pyright#GetExecutable'](buffer),
    formatter = vim.fn['ale#fixers#ruff_format#GetExecutable'](buffer),
  }
  for name, executable in pairs(tools) do
    if vim.fn.executable(executable) == 0 then
      warn(name .. ' unavailable: ' .. executable)
    end
  end
  for _, item in ipairs(vim.fn['ale#history#Get'](buffer)) do
    if item.status == 'failed' or (item.exit_code and item.exit_code > 1) then
      warn('checker failed: ' .. vim.inspect(item.command))
    end
  end
  return tools
end

function M.setup()
  if vim.b.dotfiles_python_loaded then
    return
  end
  vim.b.dotfiles_python_loaded = true
  vim.b.ale_linters = { 'ruff', 'pyright' }
  vim.b.ale_fixers = { 'ruff_format' }
  vim.b.ale_fix_on_save = 0
  -- ALE searches the nearest virtualenv before PATH. Explicit executable
  -- overrides are authoritative, even when that project has another checker.
  for _, tool in ipairs({ 'ruff', 'ruff_format', 'pyright' }) do
    local key = 'ale_python_' .. tool
    local selected = vim.b[key .. '_executable'] or vim.g[key .. '_executable']
    local default = tool == 'pyright' and 'pyright-langserver' or 'ruff'
    if selected and selected ~= default then
      vim.b[key .. '_use_global'] = 1
    end
  end
  vim.bo.omnifunc = 'ale#completion#OmniFunc'
  local function map(mode, lhs, rhs, description)
    vim.keymap.set(mode, lhs, rhs, { buffer = true, silent = true, desc = description })
  end
  map('n', '<leader>pf', '<Cmd>ALEFix<CR>', 'Python: Ruff format')
  map('n', '[d', '<Cmd>ALEPreviousWrap<CR>', 'Previous diagnostic')
  map('n', ']d', '<Cmd>ALENextWrap<CR>', 'Next diagnostic')
  map('n', 'gd', '<Cmd>ALEGoToDefinition<CR>', 'Python: definition')
  map('n', 'K', '<Cmd>ALEHover<CR>', 'Python: hover')
  vim.api.nvim_buf_create_user_command(0, 'PythonTools', M.inspect, {
    desc = 'Check Python executable availability and ALE command failures',
  })
  -- Load the pinned backends for inspection even when linting is disabled.
  vim.fn['ale#linter#Get']('python')
  if not listening then
    listening = true
    local group = vim.api.nvim_create_augroup('dotfiles_python', { clear = true })
    -- ALE sends didChangeConfiguration but its native Neovim transport does
    -- not populate client.settings. Pyright requests section "python" from
    -- Neovim; bridge ALE's existing config into that transport's settings.
    vim.api.nvim_create_autocmd('User', {
      pattern = 'ALELSPStarted',
      group = group,
      callback = function()
        if vim.bo.filetype ~= 'python' then
          return
        end
        local buffer = vim.api.nvim_get_current_buf()
        -- ALE names its connections executable:project_root. Match this
        -- buffer's native Pyright resolution, not every attached ALE client
        -- that happens to have a "python" configuration section.
        local executable = vim.fn['ale_linters#python#pyright#GetExecutable'](buffer)
        local root = vim.fn['ale_linters#python#pyright#GetCwd'](buffer)
        local connection = executable .. ':' .. (root == vim.NIL and '' or root)
        for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
          if client.name == connection then
            local config = vim.fn['ale#lsp#GetConnectionConfig'](client.name)
            if config.python and not vim.deep_equal(client.settings, config) then
              client.settings = config
              client:notify('workspace/didChangeConfiguration', { settings = config })
            end
          end
        end
      end,
    })
    vim.api.nvim_create_autocmd('User', {
      pattern = 'ALELintPost',
      group = group,
      callback = function()
        if vim.bo.filetype == 'python' then
          M.inspect()
        end
      end,
    })
  end
  M.inspect()
end

return M
