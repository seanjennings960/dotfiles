"""Explicit locked test setup and a runner for this repository only."""

import hashlib
import os
from pathlib import Path
import subprocess
import sys
import venv

import click

from .process import replace


def source_root():
    return Path(os.environ.get("DOTFILES_SOURCE", Path(__file__).resolve().parents[1])).resolve()


def test_python():
    override = os.environ.get("DOTFILES_TEST_PYTHON")
    if override:
        # Resolving the executable symlink can bypass its virtualenv's pyvenv.cfg.
        return Path(override).expanduser().absolute()
    lock = source_root() / "requirements-dev.lock"
    if not lock.is_file():
        raise click.ClickException(f"Repository test lock is missing: {lock}")
    identity = hashlib.sha256(lock.read_bytes()).hexdigest()[:16]
    cache = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
    return cache / "dotfiles" / "tests" / identity / "bin" / "python"


def setup():
    python = test_python()
    venv.EnvBuilder(with_pip=True).create(python.parent.parent)
    subprocess.run([str(python), "-m", "pip", "install", "-r",
                    str(source_root() / "requirements-dev.lock")], check=True)
    click.echo(f"Test environment: {python}")


def run(args):
    root = source_root()
    if not (root / "tests").is_dir():
        raise click.ClickException(f"Repository tests are missing: {root}")
    python = test_python()
    if not python.is_file():
        raise click.ClickException(
            f"Missing test environment: {python}\n"
            "Provision explicitly with the launcher's Python: python -m dotfiles_dev.testing --setup"
        )
    # Validate all locked distributions without importing project modules or startup code.
    probe = """import importlib.metadata as m, pathlib, sys
for line in pathlib.Path(sys.argv[1]).read_text().splitlines():
    if line and not line.startswith('#'):
        name, version = line.split('==')
        if m.version(name) != version:
            raise SystemExit(f'{name} does not match the repository test lock')
"""
    try:
        result = subprocess.run([str(python), "-I", "-c", probe, str(root / "requirements-dev.lock")],
                                capture_output=True, text=True)
    except OSError as error:
        raise click.ClickException(f"Cannot run the test interpreter: {error}")
    if result.returncode:
        raise click.ClickException("Test environment is incomplete or differs from the lock. "
                                   "Run explicit test setup.\n" + result.stderr.strip())
    environment = dict(os.environ)
    # Test imports use installed source, not whichever project invoked dev test.
    environment["PYTHONPATH"] = str(root)
    environment.pop("PYTHONHOME", None)
    replace([python, "-m", "pytest", *args], root, environment)


if __name__ == "__main__":
    if sys.argv[1:] != ["--setup"]:
        raise SystemExit("Usage: python -m dotfiles_dev.testing --setup")
    setup()
