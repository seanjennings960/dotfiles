"""Real Neovim startup, editing, plugin and persistence contracts."""

import json
import shutil
from pathlib import Path

import pexpect
import pytest


def probe(run, repo_root, workspace, lua, *files, expected_stderr=""):
    script = workspace / "probe.lua"
    result = workspace / "result.json"
    script.write_text(
        f"local config_after = {json.dumps(str(repo_root / 'nvim/after'))}\n"
        "local result = (function()\n" + lua + "\nend)()\n"
        f"vim.fn.writefile({{vim.json.encode(result)}}, {json.dumps(str(result))})\n"
    )
    process = run([
        "nvim", "--headless", "-u", repo_root / "nvim/init.lua", *files,
        "-c", f"luafile {script}", "-c", "qa!",
    ])
    assert process.stderr == expected_stderr, process.stderr
    return json.loads(result.read_text())


def test_startup_options_and_real_plugins(run, repo_root, workspace):
    result = probe(run, repo_root, workspace, """
      vim.cmd('NERDTreeToggle')
      local tree = vim.bo.filetype
      vim.cmd('NERDTreeToggle')
      vim.cmd('CtrlP')
      local finder = vim.fn.bufname('%')
      vim.cmd('call ctrlp#exit()')
      return {
        tree = tree, finder = finder, theme = vim.g.colors_name,
        leader = vim.g.mapleader, number = vim.wo.number,
        expandtab = vim.bo.expandtab, shiftwidth = vim.bo.shiftwidth,
        ignorecase = vim.o.ignorecase, smartcase = vim.o.smartcase,
        incsearch = vim.o.incsearch, hlsearch = vim.o.hlsearch,
        whitespace = vim.fn.exists(':StripWhitespace'),
        ale = vim.fn.exists(':ALEInfo'), airline = vim.g.loaded_airline,
        gundo = vim.fn.exists(':GundoToggle'),
        python_after = vim.tbl_contains(vim.opt.rtp:get(),
          config_after),
        errors = vim.v.errmsg,
      }
    """, expected_stderr=">>> _")  # CtrlP draws its prompt even in headless mode.
    assert result == {
        "tree": "nerdtree", "finder": "ControlP", "theme": "gruvbox",
        "leader": ",", "number": True, "expandtab": True, "shiftwidth": 4,
        "ignorecase": True, "smartcase": True, "incsearch": True,
        "hlsearch": True, "whitespace": 2, "ale": 2, "airline": 1,
        "gundo": 0, "python_after": True, "errors": "",
    }


@pytest.mark.parametrize("suffix,filetype", [("yaml", "yaml"), ("md", "markdown")])
def test_filetype_defaults_and_editorconfig(run, repo_root, workspace, suffix, filetype):
    file = workspace / f"sample.{suffix}"
    file.write_text("one\n")
    lua = """
      vim.cmd('normal! >>')
      return {ft = vim.bo.filetype, sw = vim.bo.shiftwidth,
        ts = vim.bo.tabstop, sts = vim.bo.softtabstop, et = vim.bo.expandtab,
        line = vim.api.nvim_get_current_line()}
    """
    assert probe(run, repo_root, workspace, lua, file) == {
        "ft": filetype, "sw": 2, "ts": 2, "sts": 2, "et": True, "line": "  one",
    }
    (workspace / ".editorconfig").write_text(
        "root = true\n[*]\nindent_style = tab\nindent_size = 3\ntab_width = 3\n"
    )
    result = probe(run, repo_root, workspace, lua, file)
    assert result["ft"] == filetype
    assert result["sw"] == result["ts"] == 3
    assert result["et"] is False
    assert result["line"] == "\tone"


def test_effective_core_maps(run, repo_root, workspace):
    result = probe(run, repo_root, workspace, """
      vim.api.nvim_feedkeys(',i,N', 'xt', false)
      local toggled = {vim.wo.list, vim.wo.number}
      vim.api.nvim_feedkeys(',n', 'xt', false)
      local tree = vim.bo.filetype
      vim.api.nvim_feedkeys(',n', 'xt', false)
      vim.api.nvim_feedkeys(vim.keycode('<C-p>'), 'xt', false)
      local finder = vim.fn.bufname('%')
      vim.cmd('call ctrlp#exit()')
      vim.api.nvim_feedkeys(vim.keycode('<F4>'), 'xt', false)
      return {toggled = toggled, tree = tree, finder = finder,
        undo_map = vim.fn.maparg(',u', 'n'), errors = vim.v.errmsg}
    """, expected_stderr=">>> _")
    assert result == {
        "toggled": [True, False], "tree": "nerdtree", "finder": "ControlP",
        "undo_map": "", "errors": "",
    }


def test_copy_only_clipboard_local_paste(run, repo_root, workspace):
    result = probe(run, repo_root, workspace, """
      vim.opt.clipboard = ''
      vim.fn.setreg('"', {'local first', 'local second'}, 'V')
      vim.opt.clipboard = 'unnamedplus'
      vim.cmd('normal! "+p')
      return {lines = vim.api.nvim_buf_get_lines(0, 0, -1, false),
        provider = vim.g.clipboard.name, errors = vim.v.errmsg}
    """)
    assert result == {
        "lines": ["", "local first", "local second"],
        "provider": "OSC 52 (copy only)", "errors": "",
    }


def test_terminal_save_and_persistent_undo(terminal, run, repo_root, workspace, env):
    file = workspace / "edited.txt"
    child = terminal("nvim", ["-u", repo_root / "nvim/init.lua", file])
    child.expect("edited.txt")
    child.send("ihello from a real terminal")
    child.send("\x1b")
    child.send(":wq\r")
    child.expect(pexpect.EOF)
    child.close()
    assert child.exitstatus == 0
    assert file.read_text() == "hello from a real terminal\n"
    state = Path(env["XDG_STATE_HOME"]) / "nvim"
    for name in ("undo", "swap", "backup"):
        assert (state / name).is_dir()
    assert list((state / "undo").iterdir())
    result = probe(run, repo_root, workspace, """
      local before = vim.api.nvim_get_current_line()
      vim.cmd('silent undo')
      return {before = before, after = vim.api.nvim_get_current_line(),
        undo = vim.o.undodir, swap = vim.o.directory, backup = vim.o.backupdir}
    """, file)
    assert result["before"] == "hello from a real terminal"
    assert result["after"] == ""
    for name, option in (("undo", "undo"), ("swap", "swap"), ("backup", "backup")):
        assert result[option] == str(state / name) + "//"


def test_external_local_hook_and_symlink(run, repo_root, workspace, env):
    config = Path(env["XDG_CONFIG_HOME"])
    config.mkdir(parents=True)
    (config / "nvim").symlink_to(repo_root / "nvim", target_is_directory=True)
    local = config / "dotfiles/nvim-local.lua"
    local.parent.mkdir()
    local.write_text("vim.g.dotfiles_trial = 'loaded'\n")
    assert probe(run, repo_root, workspace, "return vim.g.dotfiles_trial") == "loaded"
    process = run(["nvim", "--headless", "+lua assert(vim.g.dotfiles_trial == 'loaded')", "+qa!"])
    assert process.stderr == ""
    local.write_text("error('trial failure must be visible')\n")
    process = run(["nvim", "--headless", "-u", repo_root / "nvim/init.lua", "+qa!"], check=False)
    assert "trial failure must be visible" in process.stderr


def test_missing_baseline_plugin_is_actionable(run, repo_root, workspace):
    # Copy just core configuration: an empty plugin tree must never pass startup.
    isolated = workspace / "isolated"
    shutil.copytree(repo_root / "nvim", isolated / "nvim")
    process = run(["nvim", "--headless", "-u", isolated / "nvim/init.lua", "+qa!"], check=False)
    assert "Missing pinned plugin gruvbox" in process.stderr
    assert "git submodule update --init --recursive --checkout" in process.stderr
