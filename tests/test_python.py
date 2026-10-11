"""Python milestone behavior with the pinned ALE, Ruff, and Pyright processes."""

import json
import time

import pexpect
import pytest
from python_fixture_helpers import (
    codes,
    editor,
    editor_init,
    forwarding_ruff,
    lua,
    marker_venv,
    project,
    pyright,
    terminal_format,
)

FORMAT = """
vim.cmd('ALEFix')
assert(vim.wait(10000, function()
  return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\\n') == expected
end, 50), 'format timeout')
"""


def test_default_lint_type_and_format(run, repo_root, tmp_path, workspace):
    _, source = project(workspace, 'import os\nvalue:int="wrong"\n')
    lint = run(["ruff", "check", "--output-format", "json", source], check=False)
    assert lint.returncode == 1
    assert any(d["code"] == "F401" for d in json.loads(lint.stdout))
    assert any(d["rule"] == "reportAssignmentType" for d in pyright(run, source))
    formatted = terminal_format(run, source)
    data = editor(
        run, repo_root, tmp_path, source,
        wait='has("ruff") and has("pyright", "is not assignable")',
        after=f"local expected = {lua(formatted.rstrip(chr(10)))}\n" + FORMAT,
    )
    assert ("ruff", "F401") in codes(data)
    assert data["linters"] == ["ruff", "pyright"]
    assert "\n".join(data["lines"]) + "\n" == formatted
    assert data["tools"] == {"ruff": "ruff", "formatter": "ruff", "pyright": "pyright-langserver"}
    assert "''ruff'' check" in data["info"]


def test_ale_definition_jump(run, repo_root, tmp_path, workspace):
    _, source = project(workspace, 'def target() -> int:\n    return 42\nvalue: str = target()\n')
    editor(
        run, repo_root, tmp_path, source,
        wait='has("pyright", "is not assignable")',
        after='''
assert(vim.bo.omnifunc == 'ale#completion#OmniFunc')
vim.api.nvim_win_set_cursor(0, {3, 15})
vim.cmd('ALEGoToDefinition')
assert(vim.wait(10000, function()
  return vim.api.nvim_win_get_cursor(0)[1] == 1
end, 50), 'definition timeout')
''',
    )


def test_ale_hover_documentation(run, repo_root, tmp_path, workspace):
    _, source = project(
        workspace,
        'def target() -> int:\n    """Local target fixture documentation."""\n'
        '    return 42\nvalue: str = target()\n',
    )
    editor(
        run, repo_root, tmp_path, source,
        wait='has("pyright", "is not assignable")',
        after='''
vim.g.ale_hover_to_preview = 1
vim.g.ale_hover_to_floating_preview = 0
vim.g.ale_floating_preview = 0
vim.api.nvim_win_set_cursor(0, {4, 15})
vim.cmd('ALEHover')
assert(vim.wait(10000, function()
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buffer) and vim.bo[buffer].filetype == 'ale-preview.message' then
      local text = table.concat(vim.api.nvim_buf_get_lines(buffer, 0, -1, false), '\\n')
      if text:find('target', 1, true) and text:find('-> int', 1, true)
        and text:find('Local target fixture documentation.', 1, true) then
        return true
      end
    end
  end
  return false
end, 50), 'hover documentation timeout')
''',
    )


def test_settings_bridge_leaves_other_ale_client_alone(run, repo_root, tmp_path, workspace):
    _, source = project(workspace, 'value: int = "wrong"\n')
    editor(
        run, repo_root, tmp_path, source,
        wait='has("pyright", "is not assignable")',
        after=r'''
local buffer = vim.api.nvim_get_current_buf()
local root = vim.fn['ale#python#FindProjectRoot'](buffer)
vim.fn['ale#linter#GetAll']({'python'})
vim.fn['ale#linter#Define']('python', {
  name = 'python_auxiliary', lsp = 'stdio', project_root = root,
  executable = '/usr/local/bin/pyright-langserver',
  command = '/usr/local/bin/pyright-langserver --stdio',
  lsp_config = {python = {analysis = {autoSearchPaths = false}}},
})
vim.cmd([[
function! PythonAuxReady(linter, details) abort
  let g:python_auxiliary_ready = 1
endfunction
call ale#lsp_linter#StartLSP(bufnr(''),
  \ filter(ale#linter#GetAll(['python']), {_, item -> item.name ==# 'python_auxiliary'})[0],
  \ function('PythonAuxReady'))
]])
assert(vim.wait(10000, function() return vim.g.python_auxiliary_ready == 1 end, 50),
  'auxiliary server startup timeout')
local found = false
for _, client in ipairs(vim.lsp.get_clients({bufnr = buffer})) do
  if client.name == '/usr/local/bin/pyright-langserver:' .. root then
    found = true
    assert(client.initialized, 'auxiliary real Pyright client did not initialize')
    assert(vim.fn['ale#lsp#GetConnectionConfig'](client.name).python,
      'auxiliary ALE config was not delivered')
    assert(client.settings.python == nil, 'Python bridge mutated the auxiliary client')
  end
end
assert(found, 'auxiliary ALE client was not attached')
''',
    )


def test_ale_omnifunc_completion_in_terminal(terminal, repo_root, tmp_path, workspace):
    _, source = project(workspace, 'import os\nvalue: int = "wrong"\nos.pa\n')
    result = tmp_path / "completion.json"
    script = tmp_path / "completion.lua"
    script.write_text(
        '''
vim.cmd('ALELint')
assert(vim.wait(20000, function()
  local info = vim.g.ale_buffer_info[tostring(vim.api.nvim_get_current_buf())] or {}
  for _, diagnostic in ipairs(info.loclist or {}) do
    if diagnostic.linter_name == 'pyright' and diagnostic.code == 'reportAssignmentType' then
      return true
    end
  end
  return false
end, 50), 'completion server startup timeout')
vim.fn.timer_start(50, function(timer)
  if vim.fn.pumvisible() == 1 then
    local data = {items = vim.b.ale_completion_result, menu = vim.fn.complete_info(), mode = vim.fn.mode()}
'''
        + f"    vim.fn.writefile({{vim.json.encode(data)}}, {lua(result)})\n"
        + '''
    vim.fn.timer_stop(timer)
  end
end, {['repeat'] = -1})
vim.api.nvim_echo({{'PYTHON_READY', 'None'}}, true, {})
'''
    )
    child = terminal(
        "nvim", ["-u", editor_init(repo_root, tmp_path), source, "-c", f"luafile {script}"],
        timeout=30,
    )
    child.expect("PYTHON_READY")
    child.send("GA\x18\x0f")  # End of os.pa, Insert, Ctrl-X Ctrl-O: actual ALE omnifunc.
    deadline = time.monotonic() + 10
    while not result.exists() and time.monotonic() < deadline:
        time.sleep(0.05)
    assert result.exists(), "ALE completion popup did not appear within 10 seconds"
    data = json.loads(result.read_text())
    assert data["mode"] == "i"
    assert {"path", "pardir"} <= {item["word"] for item in data["items"]}
    assert any(item["word"] == "path" for item in data["menu"]["items"])
    child.send("\x05\x1b:qa!\r")  # Cancel completion, leave Insert, quit without saving.
    child.expect(pexpect.EOF)


@pytest.mark.parametrize("policy", ["toml", "json"])
def test_native_project_policy_outside_root(run, repo_root, tmp_path, workspace, policy):
    config = '''[tool.ruff]
line-length = 40
[tool.ruff.lint]
ignore = ["F401"]
[tool.ruff.format]
quote-style = "single"
'''
    root, source = project(
        workspace,
        'import os\nvalue:int="wrong"\nitems=["aaaaaaaaaa", "bbbbbbbbbb", "cccccccccc", "dddddddddd"]\nunknown_name\n',
        config,
    )
    if policy == "toml":
        with (root / "pyproject.toml").open("a") as handle:
            handle.write('[tool.pyright]\nreportAssignmentType = "none"\n')
    else:
        (root / "pyrightconfig.json").write_text('{"reportAssignmentType": "none"}')
    lint = run(["ruff", "check", "--output-format", "json", source], check=False)
    assert all(d["code"] != "F401" for d in json.loads(lint.stdout))
    types = pyright(run, source)
    assert any(d["rule"] == "reportUndefinedVariable" for d in types)
    assert not any(d["rule"] == "reportAssignmentType" for d in types)
    formatted = terminal_format(run, source)
    assert "'aaaaaaaaaa'" in formatted
    assert "items = [\n" in formatted
    data = editor(
        run, repo_root, tmp_path, source,
        wait='has("pyright", "unknown_name") and has("ruff", "Undefined name")',
        after=f"local expected = {lua(formatted.rstrip(chr(10)))}\n" + FORMAT,
    )
    assert data["root"] == str(root)
    assert ("ruff", "F401") not in codes(data)
    assert not any("is not assignable" in d["text"] for d in data["diagnostics"])
    assert "\n".join(data["lines"]) + "\n" == formatted


@pytest.mark.parametrize("selection", ["project", "activated", "explicit"])
def test_interpreter_and_local_typed_package(
    run, env, repo_root, tmp_path, workspace, selection,
):
    root, source = project(
        workspace, 'import dotfiles_local_marker\nvalue: str = dotfiles_local_marker.answer\n',
    )
    path = root / ".venv" if selection == "project" else workspace / "chosen-env"
    python = marker_venv(run, path)
    before = ""
    if selection == "activated":
        env["VIRTUAL_ENV"] = str(path)
        env["PATH"] = str(path / "bin") + ":" + env["PATH"]
    if selection == "explicit":
        # A competing, empty project venv must not override explicit pythonPath.
        run(["python3", "-m", "venv", "--without-pip", root / ".venv"])
        before = f"vim.g.ale_python_pyright_config = {{python = {{pythonPath = {lua(python)}}}}}"
    cli = pyright(run, source, *([] if selection == "activated" else ["--pythonpath", python]))
    assert any(d["rule"] == "reportAssignmentType" for d in cli)
    assert not any(d["rule"] == "reportMissingImports" for d in cli)
    data = editor(
        run, repo_root, tmp_path, source, before=before,
        wait='has("pyright", "is not assignable")',
    )
    assert data["config"]["python"]["pythonPath"] == str(python)
    assert not any("could not be resolved" in d["text"] for d in data["diagnostics"])
    assert any(settings["python"]["pythonPath"] == str(python) for settings in data["settings"])
    # Interpreter selection is independent of the PATH-supplied checker.
    assert data["tools"]["pyright"] == "pyright-langserver"
    if selection == "project":
        unselected = pyright(run, source)
        assert any(d["rule"] == "reportMissingImports" for d in unselected)


def test_project_checker_and_authoritative_override(run, repo_root, tmp_path, workspace):
    root, source = project(workspace, 'import os\nvalue:int=1\n')
    marker_venv(run, root / ".venv")
    log = workspace / "ruff-invocations"
    local = root / ".venv/bin/ruff"
    forwarding_ruff(local, log)
    assert run([local, "--version"]).stdout.strip() == "ruff 0.16.10"
    formatted = terminal_format(run, source)
    data = editor(
        run, repo_root, tmp_path, source, wait='has("ruff")',
        after=f"local expected = {lua(formatted.rstrip(chr(10)))}\n" + FORMAT,
    )
    assert data["tools"]["ruff"] == str(local)
    assert data["tools"]["formatter"] == str(local)
    assert "--version" in log.read_text()
    assert "check -q" in log.read_text()
    assert "format --stdin-filename" in log.read_text()
    assert ("ruff", "F401") in codes(data)
    log.unlink()
    selected = workspace / "selected-ruff"
    forwarding_ruff(selected, log)
    data = editor(
        run, repo_root, tmp_path, source, wait='has("ruff")',
        before=f"vim.g.ale_python_ruff_executable = {lua(selected)}",
    )
    assert data["tools"]["ruff"] == str(selected)
    assert str(selected) in data["info"]
    assert "check -q" in log.read_text()


@pytest.mark.parametrize("state", ["unavailable", "failed", "disabled"])
def test_disable_and_checker_failures(run, repo_root, tmp_path, workspace, state):
    root, source = project(workspace, 'import os\nvalue: int = "wrong"\n')
    marker_venv(run, root / ".venv")
    fallback_log = workspace / "fallback-used"
    forwarding_ruff(root / ".venv/bin/ruff", fallback_log)
    missing = workspace / "missing-ruff"
    before = f"vim.g.ale_python_ruff_executable = {lua(missing)}\n"
    if state == "failed":
        missing.write_text('#!/bin/sh\nprintf "deliberate checker failure\\n" >&2\nexit 2\n')
        missing.chmod(0o755)
    if state == "disabled":
        before += "vim.g.ale_enabled = 0\n"
        # Set buffer-local disable before the Python ftplugin runs.
        before += "vim.api.nvim_create_autocmd('BufReadPre', {callback = function() vim.b.ale_enabled = 0 end})\n"
    data = editor(
        run, repo_root, tmp_path, source, before=before,
        wait='true' if state == "disabled" else 'has("pyright", "is not assignable")',
    )
    assert not any(d["linter_name"] == "ruff" for d in data["diagnostics"])
    assert not fallback_log.exists()
    if state == "disabled":
        assert not data["diagnostics"]
        assert not data["history"]
    else:
        assert data["tools"]["ruff"] == str(missing)
        assert str(missing) in data["messages"]
        assert ("unavailable" if state == "unavailable" else "checker failed") in data["messages"]
        if state == "failed":
            assert "deliberate checker failure" in data["info"]
