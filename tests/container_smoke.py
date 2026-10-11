"""Exercise the installed launcher in a disposable Feature-enabled container."""

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def run(arguments, cwd, environment):
    return subprocess.run(arguments, cwd=cwd, env=environment,
                          text=True, capture_output=True, check=False)


def main():
    assert os.getuid() != 0, "Run the smoke check as the development user"
    dev = shutil.which("dev")
    assert dev, "The Feature must install dev on PATH"
    environment = dict(os.environ)
    assert environment.get("DEV_ENVIRONMENT") == "container"
    with tempfile.TemporaryDirectory(prefix="dev-smoke-") as directory:
        root = Path(directory)
        project = root / "project with spaces"
        project.mkdir()
        subprocess.run(["git", "init", "--quiet", str(project)], check=True)
        cwd = project / "nested"
        cwd.mkdir()
        environment["DOTFILES_TMUX_SOCKET"] = str(root / "tmux.sock")
        try:
            # A fresh project venv has no Click. It must not affect dev's runtime.
            venv = project / ".venv"
            subprocess.run([sys.executable, "-m", "venv", "--without-pip", str(venv)], check=True)
            environment["VIRTUAL_ENV"] = str(venv)
            environment["PATH"] = f"{venv / 'bin'}:{environment['PATH']}"
            result = run([dev, "env"], cwd, environment)
            assert result.returncode == 0, result.stderr
            assert "Environment: container" in result.stdout, result.stdout
            assert f"Workspace: {project}" in result.stdout, result.stdout
            assert f"Directory: {cwd}" in result.stdout, result.stdout

            result = run([dev, "exec", "python", "-c", "import sys; print(sys.prefix)"], cwd, environment)
            assert result.returncode == 0, result.stderr
            assert result.stdout.strip() == str(venv), result.stdout

            code = "import json, os, sys; print(json.dumps([os.getcwd(), sys.argv[1:]])); sys.stderr.write('stderr preserved'); sys.exit(7)"
            result = run([dev, "exec", "python", "-c", code, "a b", "--help"], cwd, environment)
            assert result.returncode == 7, result
            assert json.loads(result.stdout) == [str(cwd), ["a b", "--help"]]
            assert result.stderr == "stderr preserved", result.stderr

            # Two fresh launcher processes must discover the same tmux session.
            code = "from dotfiles_dev.local import Local; from dotfiles_dev.workspace import Workspace; print(Local('container').ensure(Workspace.discover()))"
            first = run([sys.executable, "-I", "-c", code], cwd, environment)
            second = run([sys.executable, "-I", "-c", code], cwd, environment)
            assert first.returncode == second.returncode == 0, (first.stderr, second.stderr)
            assert first.stdout.strip() and first.stdout == second.stdout
        finally:
            subprocess.run(["tmux", "-S", environment["DOTFILES_TMUX_SOCKET"], "kill-server"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    print("PASS: installed dev, workspace discovery, project venv isolation, exec, tmux reconnection")


if __name__ == "__main__":
    main()
