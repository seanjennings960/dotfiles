"""Acceptance through installed dev, activated startup, and real checkers."""

import json
from pathlib import Path

import pytest
from python_fixture_helpers import forwarding_ruff, lua, marker_venv, project


@pytest.fixture
def activated(run, launcher, repo_root, env):
    env["DOTFILES_SOURCE"] = str(repo_root)
    run([*launcher, "activate"])
    run([*launcher, "activate"])
    return launcher


@pytest.mark.parametrize("policy", [False, True])
def test_native_language_inspection(run, activated, env, workspace, policy):
    config = '[tool.ruff]\nline-length = 60\n[tool.ruff.lint]\nignore = ["F401"]\n' if policy else ""
    root, source = project(workspace, 'import os\nvalue: int = "wrong"\n', config)
    python = marker_venv(run, root / ".venv")
    log = workspace / "checker-log"
    forwarding_ruff(root / ".venv/bin/ruff", log)
    before = {path: path.read_bytes() for path in (source, root / "pyproject.toml")}
    result = run([*activated, "languages", source, "--json"], timeout=40)
    report = json.loads(result.stdout)
    editor = report["editor"]
    assert editor["status"] == "resolved", editor
    assert editor["settled"]
    assert editor["interpreter"] == str(python)
    assert editor["ruff"]["path"] == str(root / ".venv/bin/ruff")
    assert editor["formatter"]["path"] == str(root / ".venv/bin/ruff")
    assert editor["pyright"]["connection"] == "initialized"
    assert editor["pyright"]["settings"]["python"]["pythonPath"] == str(python)
    assert "--show-settings" in log.read_text()
    assert editor["ruff"]["settings_report"]["source"] == (str(root / "pyproject.toml") if policy else None)
    assert report["terminal"]["ruff"]["path"] == "/usr/local/bin/ruff"
    assert report["differences"]
    assert report["agent"]["status"] == "unresolved"
    if policy:
        assert "linter.line_length = 60" in editor["ruff"]["settings_report"]["stdout"]
    assert all(path.read_bytes() == value for path, value in before.items())


@pytest.mark.parametrize("state", ["unavailable", "disabled", "failed"])
def test_inspection_reports_authoritative_override(run, activated, env, workspace, state):
    root, source = project(workspace, "value = 1\n")
    marker_venv(run, root / ".venv")
    fallback_log = workspace / "fallback"
    forwarding_ruff(root / ".venv/bin/ruff", fallback_log)
    selected = workspace / "explicit-ruff"
    config = Path(env["XDG_CONFIG_HOME"]) / "dotfiles/nvim-local.lua"
    if state == "failed":
        selected.write_text("#!/bin/sh\necho deliberate-failure >&2\nexit 2\n")
        selected.chmod(0o755)
    config.write_text(f"vim.g.ale_python_ruff_executable = {lua(selected)}\n"
                      + f"vim.g.ale_python_ruff_format_executable = {lua(selected)}\n"
                      + ("vim.g.ale_linters = {python = {'pyright'}}\n" if state == "disabled" else ""))
    report = json.loads(run([*activated, "languages", source, "--json"], timeout=40).stdout)
    tool = report["editor"]["ruff"]
    if state == "failed":
        assert tool["version"]["status"] == "failed"
        assert tool["settings_report"]["status"] == "failed"
    else:
        assert tool["status"] == state
    assert not fallback_log.exists(), "Explicit selection silently fell back to the project checker"


def test_inspection_without_activation_is_unresolved(run, launcher, workspace):
    _, source = project(workspace, "value = 1\n")
    report = json.loads(run([*launcher, "languages", source, "--json"], timeout=40).stdout)
    assert report["editor"]["status"] == "unresolved"
    assert "Normal Neovim startup" in report["editor"]["error"]


@pytest.mark.parametrize("disabled", [False, True])
def test_unconfigured_workspace_and_independent_formatter(run, activated, env, workspace, disabled):
    source = workspace / "example.py"
    source.write_text('value: int = "wrong"\n')
    if disabled:
        (Path(env["XDG_CONFIG_HOME"]) / "dotfiles/nvim-local.lua").write_text("vim.g.ale_enabled = 0\n")
    editor = json.loads(run([*activated, "languages", source, "--json"], timeout=40).stdout)["editor"]
    assert editor["status"] == "resolved", editor
    assert editor["interpreter"] is None, "An uninferred interpreter must stay unresolved"
    assert editor["ruff"]["status"] == ("disabled" if disabled else "resolved")
    assert editor["pyright"]["status"] == ("disabled" if disabled else "resolved")
    assert editor["formatter"]["status"] == "resolved", "ALEDisable does not disable explicit formatting"
    assert editor["settled"], editor["pyright"]


def test_normal_startup_definition_diagnostic_format_and_check(run, activated, workspace, tmp_path):
    root, source = project(workspace, 'def target() -> int:\n    return 42\nvalue:str=target()\n')
    python = marker_venv(run, root / ".venv")
    output = tmp_path / "result.json"
    script = tmp_path / "acceptance.lua"
    script.write_text("""
local ok, err = xpcall(function()
assert(vim.g.dotfiles_initialized == 1)
vim.cmd('ALELint')
assert(vim.wait(15000, function()
  local info = vim.g.ale_buffer_info[tostring(vim.api.nvim_get_current_buf())] or {}
  for _, diagnostic in ipairs(info.loclist or {}) do
    if diagnostic.linter_name == 'pyright' and diagnostic.code == 'reportAssignmentType' then return true end
  end
  return false
end, 50), 'real type diagnostic missing')
vim.api.nvim_win_set_cursor(0, {3, 12})
vim.cmd('ALEGoToDefinition')
assert(vim.wait(5000, function() return vim.api.nvim_win_get_cursor(0)[1] == 1 end, 50))
vim.api.nvim_buf_set_lines(0, 2, 3, false, {'value:int=target()'})
vim.cmd('ALEFix')
assert(vim.wait(5000, function()
  return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), ' '):find('value: int = target()', 1, true)
end, 50), 'format did not complete')
vim.cmd('write')
local report = require('dotfiles.inspection').collect()
""" + f"vim.fn.writefile({{vim.json.encode(report)}}, {lua(output)})\n"
                      + "end, debug.traceback)\nif not ok then print(err); vim.cmd('cquit 1') end\nvim.cmd('qa!')\n")
    # No -u or custom bootstrap: use the activation-created XDG config.
    edited = run([*activated, "exec", "nvim", "--headless", "-c", f"luafile {script}", source],
                 cwd=root, timeout=30, check=False)
    assert edited.returncode == 0, edited.stderr
    report = json.loads(output.read_text())
    assert report["interpreter"] == str(python)
    checked = run([*activated, "exec", "pyright", "--pythonpath", python, source], cwd=root)
    assert "0 errors" in checked.stdout
    run([*activated, "exec", "ruff", "format", "--check", source], cwd=root)
    run([*activated, "exec", "ruff", "check", source], cwd=root)


@pytest.mark.parametrize("shell", ["bash", "zsh"])
def test_juliaup_preserves_project_path(run, activated, env, home, workspace, shell):
    julia = home / ".juliaup/bin"
    julia.mkdir(parents=True)
    project_bin = workspace / "bin"
    project_bin.mkdir()
    env["PATH"] = f"{project_bin}:{env['PATH']}"
    result = run([shell, "-ic", f'. "$HOME/.{shell}rc"; printf "%s\\n" "$PATH"'])
    paths = result.stdout.strip().split(":")
    assert paths[0] == str(project_bin)
    assert paths.count(str(julia)) == 1
