"""Real checker/editor fixtures; all generated state lives in pytest temp dirs."""

import json


def lua(value):
    return json.dumps(str(value))


def editor_init(repo_root, tmp_path):
    """Use production startup in combined worktrees, ALE-only on the step 1 base."""
    init = tmp_path / "python-init.lua"
    core = repo_root / "nvim/init.lua"
    bootstrap = f"dofile({lua(core)})\n" if core.is_file() else (
        f"vim.opt.runtimepath:prepend({lua(repo_root / 'vim/bundle/ale')})\n"
        f"vim.opt.runtimepath:prepend({lua(repo_root / 'nvim')})\n"
        f"vim.opt.runtimepath:append({lua(repo_root / 'nvim/after')})\n"
        "vim.cmd('filetype plugin indent on')\n"
    )
    init.write_text("vim.g.ale_history_log_output = 1\n" + bootstrap)
    return init


def editor(run, repo_root, tmp_path, source, *, before="", wait="true", after=""):
    init = editor_init(repo_root, tmp_path)
    result = tmp_path / "editor.json"
    script = tmp_path / "python-test.lua"
    script.write_text(
        "local ok, err = xpcall(function()\n"
        + before + "\n"
        + f"vim.cmd('edit ' .. vim.fn.fnameescape({lua(source)}))\n"
        + "vim.cmd('ALELint')\n"
        + "local function diagnostics()\n"
        + "return (vim.g.ale_buffer_info[tostring(vim.api.nvim_get_current_buf())] or {}).loclist or {}\nend\n"
        + "local function has(name, text)\n"
        + "for _, d in ipairs(diagnostics()) do\n"
        + "if d.linter_name == name and (not text or d.text:find(text, 1, true)) then return true end\n"
        + "end\nreturn false\nend\n"
        + f"assert(vim.wait(20000, function() return {wait} end, 50), 'diagnostic timeout')\n"
        + "local initial = diagnostics()\n"
        + after + "\n"
        + "vim.cmd('PythonTools')\n"
        + "local b = vim.api.nvim_get_current_buf()\n"
        + "local settings = {}\n"
        + "for _, client in ipairs(vim.lsp.get_clients({bufnr = b})) do table.insert(settings, client.settings) end\n"
        + "local data = {diagnostics = initial, lines = vim.api.nvim_buf_get_lines(b, 0, -1, false),\n"
        + "settings = settings,\n"
        + "tools = require('dotfiles.python').inspect(),\n"
        + "config = vim.fn['ale_linters#python#pyright#GetConfig'](b),\n"
        + "root = vim.fn['ale#python#FindProjectRoot'](b),\n"
        + "linters = vim.b.ale_linters, history = vim.fn['ale#history#Get'](b),\n"
        + "info = vim.fn.execute('ALEInfo -echo'), messages = vim.fn.execute('messages')}\n"
        + f"vim.fn.writefile({{vim.json.encode(data)}}, {lua(result)})\n"
        + "end, debug.traceback)\n"
        + f"if not ok then vim.fn.writefile({{vim.json.encode({{error = err, info = vim.fn.execute('ALEInfo -echo'), config = vim.fn['ale_linters#python#pyright#GetConfig'](vim.api.nvim_get_current_buf()), buffers = vim.g.ale_buffer_info}})}}, {lua(result)}) end\n"
        + "vim.cmd('qa!')\n"
    )
    process = run(["nvim", "--headless", "-u", init, "-c", f"luafile {script}"], timeout=35)
    data = json.loads(result.read_text())
    assert "error" not in data, (data, process.stdout, process.stderr)
    return data


def project(workspace, text, config="[tool.ruff]\n[tool.pyright]\n"):
    root = workspace / "project"
    source = root / "src" / "nested" / "example.py"
    source.parent.mkdir(parents=True)
    source.write_text(text)
    (root / "pyproject.toml").write_text(config)
    return root, source


def marker_venv(run, path):
    run(["python3", "-m", "venv", "--without-pip", path])
    python = path / "bin/python"
    site = run([python, "-c", "import sysconfig; print(sysconfig.get_path('purelib'))"]).stdout.strip()
    from pathlib import Path

    package = Path(site) / "dotfiles_local_marker"
    package.mkdir()
    (package / "__init__.py").write_text("answer: int = 42\n")
    (package / "py.typed").touch()
    return python


def pyright(run, source, *options):
    result = run(["pyright", "--outputjson", "--project", source.parents[2], *options, source], check=False)
    assert result.returncode in (0, 1), result.stderr
    return json.loads(result.stdout)["generalDiagnostics"]


def forwarding_ruff(path, log):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        f"#!/bin/sh\nprintf '%s\\n' \"$*\" >> '{log}'\n"
        'exec /usr/local/bin/ruff "$@"\n'
    )
    path.chmod(0o755)


def codes(data):
    return {(d["linter_name"], d.get("code")) for d in data["diagnostics"]}


def terminal_format(run, source):
    return run(["ruff", "format", "--stdin-filename", source, "-"], input=source.read_text()).stdout
