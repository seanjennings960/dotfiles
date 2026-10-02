"""Python milestone behavior with the pinned ALE, Ruff, and Pyright processes."""

import json

import pytest
from python_fixture_helpers import (
    codes,
    editor,
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
