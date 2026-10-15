"""Create a private virtual environment and install the dev launcher into it."""

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def _python_is_supported(python):
    result = subprocess.run(
        [str(python), "-c", "import sys; assert sys.version_info >= (3, 11)"],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return result.returncode == 0


def ensure_venv(python, venv):
    python = Path(python)
    venv = Path(venv)
    if not _python_is_supported(python):
        raise RuntimeError(f"{python} must be Python 3.11 or newer")
    if venv.is_symlink():
        raise RuntimeError(f"Refusing to use a symlink at {venv}")

    if venv.exists():
        existing_python = venv / "bin" / "python"
        if existing_python.is_file() and os.access(existing_python, os.X_OK):
            if _python_is_supported(existing_python):
                return existing_python
        backup_dir = Path(tempfile.mkdtemp(prefix="venv-backup.", dir=venv.parent))
        backup = backup_dir / "venv"
        shutil.move(str(venv), backup)
        print(f"Preserved the old virtual environment at {backup}", file=sys.stderr)

    venv.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([str(python), "-m", "venv", str(venv)], check=True)
    installed_python = venv / "bin" / "python"
    if not installed_python.is_file() or not os.access(installed_python, os.X_OK):
        raise RuntimeError(f"{venv} was created without a usable Python interpreter")
    return installed_python


def install_launcher(python, venv, source, editable=False, force_reinstall=False):
    source = Path(source)
    if not (source / "pyproject.toml").is_file():
        raise RuntimeError(f"No pyproject.toml in launcher source: {source}")
    environment_python = ensure_venv(python, Path(venv))
    command = [str(environment_python), "-m", "pip", "install", "--no-cache-dir"]
    if force_reinstall:
        command.append("--force-reinstall")
    if editable:
        command.append("--editable")
    command.append(str(source))
    subprocess.run(command, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--python", required=True, help="Interpreter used to create the environment")
    parser.add_argument("--venv", required=True, type=Path, help="Private launcher virtual environment")
    parser.add_argument("--source", required=True, type=Path, help="Directory containing launcher pyproject.toml")
    parser.add_argument("--editable", action="store_true", help="Install the source in editable mode")
    parser.add_argument("--force-reinstall", action="store_true")
    args = parser.parse_args()
    try:
        install_launcher(args.python, args.venv, args.source, args.editable, args.force_reinstall)
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"Launcher installation failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
