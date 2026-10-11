"""Inspect native editor selections and CLI reports without editing project policy."""

import json
import os
import re
import shlex
import shutil
import signal
import subprocess
import tempfile
from pathlib import Path

import click

from .local import environment


def probe(argv, cwd, *, env=None, timeout=15, success=(0,)):
    """Keep failures and timeouts visible, and reap checker/editor children."""
    command = [str(arg) for arg in argv]
    try:
        with subprocess.Popen(command, cwd=cwd, env=env, text=True, start_new_session=True,
                              stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE) as process:
            try:
                stdout, stderr = process.communicate(timeout=timeout)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                stdout, stderr = process.communicate()
                return {"status": "timeout", "command": command, "cwd": str(cwd),
                        "stdout": stdout, "stderr": stderr}
        return {"status": "resolved" if process.returncode in success else "failed",
                "command": command, "cwd": str(cwd), "exit_code": process.returncode,
                "stdout": stdout, "stderr": stderr}
    except OSError as error:
        return {"status": "unavailable", "command": command, "cwd": str(cwd), "error": str(error)}


def executable(name, cwd):
    path = shutil.which(name)
    if path is None:
        return {"status": "unavailable", "selected": name, "path": None}
    version = probe([path, "--version"], cwd)
    return {"status": version["status"], "selected": name, "path": path,
            "version": (version.get("stdout", "") or version.get("stderr", "")).strip()}


def ruff_settings(tool, file):
    if tool.get("status") != "resolved" or not tool.get("enabled", True):
        return {"status": tool["status"]}
    # These options are argv, not shell code. Unrepresentable overrides fail
    # visibly rather than being silently dropped or replaced with defaults.
    try:
        options = shlex.split(tool.get("options", ""))
    except ValueError as error:
        return {"status": "unresolved", "error": str(error)}
    result = probe([tool["path"], "check", "--show-settings", *options, file], tool["cwd"])
    match = re.search(r'^Settings path: "(.*)"$', result.get("stdout", ""), re.MULTILINE)
    result["source"] = match[1] if match else None
    result["source_status"] = "reported by Ruff" if match else "unresolved; see native output"
    return result


def editor(file, cwd):
    nvim = shutil.which("nvim")
    if not nvim:
        return {"status": "unavailable", "error": "nvim is not installed"}
    with tempfile.TemporaryDirectory(prefix="dev-languages-") as directory:
        output = Path(directory) / "editor.json"
        env = dict(os.environ, DEV_INSPECTION_RESULT=str(output))
        command = "lua local ok,m=pcall(require,'dotfiles.inspection'); if ok then m.write() else vim.cmd('cquit 2') end"
        result = probe([nvim, "--headless", "-n", "-i", "NONE", "--cmd",
                        "let g:ale_history_log_output=1", "-c", command, "--", file],
                       cwd, env=env, timeout=20)
        if not output.is_file():
            return {"status": "unresolved", "error": "Normal Neovim startup did not produce inspection; "
                    "activate dotfiles or inspect the startup error", "process": result}
        try:
            data = json.loads(output.read_text())
        except (ValueError, OSError) as error:
            return {"status": "failed", "error": str(error), "process": result}
    if "error" in data:
        return {"status": "failed", **data, "process": result}
    data["status"] = "resolved" if result["status"] == "resolved" else result["status"]
    data["process"] = result
    for name in ("ruff", "formatter"):
        tool = data[name]
        if tool["status"] == "resolved":
            tool["version"] = executable(tool["path"], tool["cwd"])
            if tool["version"]["status"] != "resolved":
                tool["status"] = tool["version"]["status"]
        # Formatting remains explicit. The checker's native report describes
        # lint configuration; formatter options are reported, never run as fixes.
        if name == "ruff":
            tool["settings_report"] = ruff_settings(tool, file)
    return data


@click.command()
@click.argument("file", required=False, type=click.Path(exists=True, dir_okay=False, path_type=Path))
@click.option("--json", "as_json", is_flag=True, help="Include native reports and settings as JSON.")
@click.pass_obj
def languages(workspace, file, as_json):
    """Inspect Python tools. FILE additionally queries normal Neovim startup."""
    if file is not None and file.suffix not in {".py", ".pyi"}:
        raise click.ClickException("Only Python files are supported by this baseline.")
    file = file.absolute() if file is not None else None
    cwd = workspace.cwd
    terminal = {name: executable(name, cwd) for name in ("python", "ruff", "pyright", "nvim", "opencode")}
    report = {"workspace": str(workspace.root), "environment": environment(), "cwd": str(cwd),
              "terminal": terminal, "editor": {"status": "unresolved", "reason": "Provide a Python file"},
              "agent": {"status": "unresolved", "reason": "No running OpenCode LSP selection observed"},
              "differences": []}
    if file:
        terminal["ruff"]["cwd"] = str(cwd)
        terminal["ruff"]["settings_report"] = ruff_settings(terminal["ruff"], file)
        if terminal["pyright"]["path"]:
            terminal["pyright"]["settings_report"] = probe(
                [terminal["pyright"]["path"], "--verbose", file], cwd, success=(0, 1))
        report["editor"] = editor(file, cwd)
        if report["editor"]["status"] == "resolved":
            selected = report["editor"]
            for name in ("ruff", "formatter"):
                if selected[name]["path"] != terminal["ruff"]["path"]:
                    report["differences"].append(f"Editor {name} and terminal Ruff executables differ")
            if selected["interpreter"] != terminal["python"]["path"]:
                report["differences"].append("Editor interpreter differs from terminal Python or is unresolved")
            report["differences"].append("Agent selections are unresolved; parity is not established")
    agent_path = terminal["opencode"]["path"]
    if agent_path:
        settings = probe([agent_path, "debug", "config", "--pure"], cwd,
                         env=dict(os.environ, OPENCODE_DISABLE_MODELS_FETCH="true"))
        try:
            report["agent"]["configured_lsp"] = json.loads(settings.get("stdout", "")).get("lsp", {})
        except (ValueError, AttributeError):
            report["agent"]["configuration_error"] = settings
    if as_json:
        click.echo(json.dumps(report, indent=2))
    else:
        click.echo(f"Python | {report['environment']} | {cwd}")
        for name, item in terminal.items():
            version = item.get("version", "").splitlines()
            click.echo(f"Terminal {name}: {item['status']} | {item['path']} | {version[0] if version else ''}")
        selected = report["editor"]
        click.echo(f"Editor: {selected['status']}")
        if selected["status"] == "resolved":
            click.echo(f"Interpreter: {selected['interpreter'] or 'unresolved'}")
            for name in ("ruff", "formatter", "pyright"):
                item = selected[name]
                click.echo(f"Editor {name}: {item['status']} | {item['path']} | cwd={item['cwd']}")
            source = selected["ruff"].get("settings_report", {}).get("source")
            click.echo(f"Ruff settings: {source or 'unresolved; use --json for native reports'}")
        else:
            click.echo(selected.get("error", selected.get("reason", "")))
        click.echo(f"Agent: {report['agent']['status']} (configured choices are not observed selections)")
        for difference in report["differences"]:
            click.echo(f"Difference: {difference}")
