#!/usr/bin/env python3
"""Run the project checks using the toolchain supplied by formal/shell.nix."""

from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]


def run(*command: str) -> None:
    print("+ " + " ".join(command), flush=True)
    subprocess.run(command, cwd=ROOT, check=True)


def main() -> None:
    run("lean", "--version")
    run("lake", "build")
    run("lake", "env", "lean", "Audit.lean")
    run("lake", "env", "lean", "--run", "EditorMain.lean")
    run("lake", "env", "lean", "--run", "examples/DeploymentChecks.lean")
    run(sys.executable, "examples/deployment-check.py", "--native")
    print("PASS: Lean build, constructive axiom audit, editor and native deployment examples", flush=True)


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as exc:
        sys.exit(exc.returncode)
