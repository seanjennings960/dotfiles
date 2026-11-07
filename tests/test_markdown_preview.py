"""Offline renderer and editor regressions; never launch a browser or a server."""

from html.parser import HTMLParser
import os
from pathlib import Path
import subprocess

import pytest


@pytest.fixture
def renderer():
    executable = os.environ.get("DOTFILES_TEST_MARKDOWN")
    if not executable:
        pytest.skip("Set DOTFILES_TEST_MARKDOWN to the packaged renderer")
    return executable


def render(renderer, markdown):
    result = subprocess.run(
        [renderer], input=markdown, text=True, capture_output=True, timeout=10,
    )
    assert result.returncode == 0, result.stderr
    return result.stdout


def test_commonmark_and_extensions(renderer):
    html = render(renderer, "# Café\n\n**bold** and `a < b`.\n\n"
                  "| A | B |\n|---|---|\n| 1 | 2 |\n")
    assert "<h1>Café</h1>" in html
    assert "<strong>bold</strong>" in html
    assert "<code>a &lt; b</code>" in html
    assert "<table>" in html


def test_raw_html_is_not_rendered(renderer):
    html = render(renderer, '<script>RAW_BLOCK_SENTINEL</script>\n\n'
                  'Text <img src="x" onerror="RAW_INLINE_SENTINEL">.\n\n'
                  '```=html\n<iframe>BACKEND_SENTINEL</iframe>\n```\n')
    assert "RAW_BLOCK_SENTINEL" not in html
    assert "RAW_INLINE_SENTINEL" not in html
    assert "<iframe>" not in html
    assert "<script>" not in html
    assert "<img" not in html


class Elements(HTMLParser):
    def __init__(self, html):
        super().__init__()
        self.elements = []
        self.feed(html)

    def handle_starttag(self, tag, attrs):
        self.elements.append((tag, dict(attrs)))


@pytest.mark.parametrize("destination", [
    "javascript:void(0)", "JaVaScRiPt:void(0)", "vbscript:ignored",
    "file:///not-a-real-file", "data:text/html,ignored",
])
def test_unsafe_link_destinations_are_removed(renderer, destination):
    html = render(renderer, f"[label]({destination})\n\n[ref][target]\n\n"
                  f"[target]: {destination}\n")
    links = [attrs for tag, attrs in Elements(html).elements if tag == "a"]
    assert len(links) == 2
    assert all(not attrs.get("href") for attrs in links)


def test_static_page_policy(renderer):
    html = render(renderer, "![remote](https://example.invalid/image.png)\n")
    elements = Elements(html).elements
    policies = [attrs["content"] for tag, attrs in elements
                if tag == "meta" and attrs.get("http-equiv") == "Content-Security-Policy"]
    assert len(policies) == 1
    assert "default-src 'none'" in policies[0]
    assert "base-uri 'none'" in policies[0]
    assert "form-action 'none'" in policies[0]
    assert not any(tag in {"script", "iframe", "object", "link"} for tag, _ in elements)
    assert html.index("Content-Security-Policy") < html.index("<body>")


def test_unsafe_options_are_not_exposed(renderer):
    result = subprocess.run(
        [renderer, "--unsafe"], input="", text=True, capture_output=True, timeout=10,
    )
    assert result.returncode == 2
    assert not result.stdout


def test_legacy_preview_not_in_closure():
    closure = os.environ.get("DOTFILES_TEST_PREVIEW_CLOSURE")
    if not closure:
        pytest.skip("Set DOTFILES_TEST_PREVIEW_CLOSURE to the editor closure's store-paths")
    paths = Path(closure).read_text().splitlines()
    assert paths
    assert not any("markdown-preview.nvim" in path or "-nodejs-" in path for path in paths)


def test_neovim_static_preview_lifecycle(renderer, tmp_path):
    nvim = os.environ.get("DOTFILES_TEST_NVIM")
    if not nvim:
        pytest.skip("Set DOTFILES_TEST_NVIM to the packaged editor")
    home = tmp_path / "home"
    home.mkdir()
    document = tmp_path / "document with spaces; literal.md"
    document.write_text("# Saved content\n")
    script = tmp_path / "check.lua"
    script.write_text(r'''
local opened = {}
vim.ui.open = function(uri)
  table.insert(opened, vim.uri_to_fname(uri))
  return {}, nil
end
local function exists(path) return vim.uv.fs_stat(path) ~= nil end
local function check()
  assert(vim.fn.exists(":MarkdownPreview") == 2)
  for _, path in ipairs(vim.api.nvim_list_runtime_paths()) do
    assert(not path:find("markdown%-preview%.nvim"), path)
  end
  local unrelated = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(unrelated, 0, -1, false, { "UNRELATED_BUFFER_SENTINEL" })
  vim.cmd.edit(vim.fn.fnameescape(vim.env.TEST_DOCUMENT))
  vim.bo.filetype = "markdown"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "# Unsaved café" })
  assert(vim.bo.modified)
  vim.cmd.MarkdownPreview()
  assert(#opened == 1)
  local path = opened[1]
  assert(path:sub(-5) == ".html")
  assert(vim.uv.fs_stat(path).mode % 512 == 384, "Preview must be mode 0600")
  assert(vim.uv.fs_stat(vim.fs.dirname(path)).mode % 512 == 448, "Directory must be mode 0700")
  local html = table.concat(vim.fn.readfile(path), "\n")
  assert(html:find("<h1>Unsaved café</h1>", 1, true), html)
  assert(not html:find("UNRELATED_BUFFER_SENTINEL", 1, true))
  assert(vim.fn.readfile(vim.env.TEST_DOCUMENT)[1] == "# Saved content")
  vim.cmd.MarkdownPreview()
  assert(#opened == 2 and not exists(path), "Refresh must remove the prior snapshot")
  vim.cmd.MarkdownPreviewStop()
  vim.cmd.MarkdownPreviewStop()
  assert(not exists(opened[2]))
  vim.cmd.MarkdownPreviewToggle()
  assert(#opened == 3)
  vim.cmd.MarkdownPreviewToggle()
  assert(not exists(opened[3]))
  vim.cmd.MarkdownPreview()
  local buffer = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_delete(buffer, { force = true })
  assert(not exists(opened[4]), "Wiping a buffer must remove its snapshot")
  vim.cmd.enew()
  vim.bo.filetype = "text"
  assert(not pcall(vim.cmd.MarkdownPreview), "Non-Markdown buffers must be rejected")
  assert(#opened == 4)
  vim.bo.filetype = "markdown"
  local opener = vim.ui.open
  vim.ui.open = function(uri)
    table.insert(opened, vim.uri_to_fname(uri))
    return nil, "No graphical browser available"
  end
  assert(not pcall(vim.cmd.MarkdownPreview))
  assert(not exists(opened[5]), "Failed browser opens must clean up the snapshot")
  assert(not exists(vim.fs.dirname(opened[5])))
  vim.ui.open = opener
  vim.cmd.enew()
  vim.bo.filetype = "markdown"
  vim.cmd.MarkdownPreview()
  vim.fn.writefile({ opened[6] }, vim.env.TEST_EXIT_PATH)
end
local ok, err = pcall(check)
if not ok then
  io.stderr:write(tostring(err) .. "\n")
  vim.cmd("cquit 1")
else
  vim.cmd("qa!")
end
''')
    exit_path = tmp_path / "exit-path"
    env = {
        **os.environ,
        "HOME": str(home),
        "XDG_CONFIG_HOME": str(home / "config"),
        "XDG_CACHE_HOME": str(home / "cache"),
        "XDG_DATA_HOME": str(home / "data"),
        "XDG_STATE_HOME": str(home / "state"),
        "TEST_DOCUMENT": str(document),
        "TEST_EXIT_PATH": str(exit_path),
        "TEST_SCRIPT": str(script),
    }
    result = subprocess.run(
        [nvim, "--headless", "-n", "-i", "NONE", "-c", "lua dofile(vim.env.TEST_SCRIPT)"],
        env=env, text=True, capture_output=True, timeout=30,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    path = Path(exit_path.read_text().strip())
    assert not path.exists(), "Exiting the editor must remove its snapshot"
    assert not path.parent.exists()
