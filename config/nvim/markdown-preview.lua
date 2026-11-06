-- Render only the current buffer to a private static file: no HTTP or RPC server.
local previews = {}

local function stop(buffer)
  local preview = previews[buffer]
  if preview then
    vim.uv.fs_unlink(preview.path)
    vim.uv.fs_rmdir(preview.directory)
    previews[buffer] = nil
  end
end

local function preview()
  local buffer = vim.api.nvim_get_current_buf()
  if vim.bo[buffer].filetype ~= "markdown" then
    error("MarkdownPreview requires a Markdown buffer")
  end
  local markdown = table.concat(vim.api.nvim_buf_get_lines(buffer, 0, -1, false), "\n") .. "\n"
  local rendered = vim.system({ vim.g.devchain_markdown_renderer }, {
    stdin = markdown,
    text = true,
    timeout = 10000,
  }):wait()
  if rendered.code ~= 0 then
    error("Markdown rendering failed: " .. (rendered.stderr or ""))
  end

  stop(buffer)
  local directory = assert(vim.uv.fs_mkdtemp(vim.uv.os_tmpdir() .. "/devchain-markdown-XXXXXX"))
  local path = directory .. "/preview.html"
  previews[buffer] = { directory = directory, path = path }
  local ok, err = pcall(function()
    -- mkdtemp creates a 0700 directory; the rendered file is 0600 even with umask 0.
    local file = assert(vim.uv.fs_open(path, "wx", 384))
    local written, write_error = vim.uv.fs_write(file, rendered.stdout, 0)
    vim.uv.fs_close(file)
    assert(written == #rendered.stdout, write_error or "Incomplete Markdown preview write")
    local _, open_error = vim.ui.open(vim.uri_from_fname(path))
    assert(not open_error, open_error)
  end)
  if not ok then
    stop(buffer)
    error(err)
  end
end

vim.api.nvim_create_user_command("MarkdownPreview", preview, {})
vim.api.nvim_create_user_command("MarkdownPreviewStop", function()
  stop(vim.api.nvim_get_current_buf())
end, {})
vim.api.nvim_create_user_command("MarkdownPreviewToggle", function()
  local buffer = vim.api.nvim_get_current_buf()
  if previews[buffer] then
    stop(buffer)
  else
    preview()
  end
end, {})

local group = vim.api.nvim_create_augroup("DevchainMarkdownPreview", { clear = true })
vim.api.nvim_create_autocmd("BufWipeout", {
  group = group,
  callback = function(event) stop(event.buf) end,
})
vim.api.nvim_create_autocmd("VimLeavePre", {
  group = group,
  callback = function()
    for buffer in pairs(previews) do
      stop(buffer)
    end
  end,
})
