import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ACTIVATE = Path(__file__).resolve().parents[1] / "activate.sh"
ZSH = shutil.which("zsh")
BASH = shutil.which("bash")


class ActivationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="activation test ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        shutil.copyfile(ACTIVATE, self.root / "activate.sh")
        (self.root / "pyproject.toml").touch()
        (self.root / "dotfiles_dev").mkdir()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.env = {**os.environ, "PATH": str(self.bin)}

    def run_shell(self, shell, command):
        return subprocess.run(
            [shell, "-c", command], cwd=self.root, env=self.env,
            text=True, capture_output=True, timeout=10,
        )

    def executable(self, path, body):
        path.write_text("#!/bin/sh\n" + body)
        path.chmod(0o755)

    def fake_python(self, path):
        self.executable(
            path,
            'if [ "$1" = -m ] && [ "$2" = venv ] && [ "$3" != --help ]; then\n'
            '  /bin/mkdir -p "$3/bin"\n'
            '  /bin/cp "$0" "$3/bin/python"\n'
            '  /bin/cp "$0" "$3/bin/pip"\n'
            'fi\nexit 0\n',
        )

    def fake_uv(self, path):
        self.fake_python(self.bin / "downloaded-python")
        self.env["MOCK_PYTHON"] = str(self.bin / "downloaded-python")
        self.executable(
            path,
            'python_bin="$5/cpython-3.11-test/bin"\n'
            '/bin/mkdir -p "$python_bin"\n'
            '/bin/cp "$MOCK_PYTHON" "$python_bin/python3.11"\n',
        )

    @unittest.skipUnless(BASH, "Bash is required")
    def test_bash_rejection_returns_without_exiting_shell(self):
        result = self.run_shell(
            BASH, 'source ./activate.sh; status=$?; printf "survived:%s\\n" "$status"',
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("survived:1", result.stdout)
        self.assertIn("requires Zsh", result.stderr)

    @unittest.skipUnless(ZSH, "Zsh is required")
    def test_missing_python_returns_failure_and_cleans_up(self):
        result = self.run_shell(
            ZSH, 'source ./activate.sh; result=$?; '
            'print "survived:$result function:${+functions[_dotfiles_dev_activate]}"',
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("survived:1 function:0", result.stdout)
        self.assertIn("Bootstrapping Python 3.11 requires curl and sh", result.stderr)

    @unittest.skipUnless(ZSH, "Zsh is required")
    def test_err_exit_with_failure_handler_keeps_shell_open(self):
        result = self.run_shell(
            ZSH, 'setopt ERR_EXIT; source ./activate.sh || print "failed:$?"; '
            'print "survived function:${+functions[_dotfiles_dev_activate]}"',
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("failed:1", result.stdout)
        self.assertIn("survived function:0", result.stdout)

    @unittest.skipUnless(ZSH, "Zsh is required")
    def test_execution_requires_sourcing(self):
        result = subprocess.run(
            [ZSH, str(self.root / "activate.sh")], env=self.env,
            text=True, capture_output=True, timeout=10,
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn("Source this script from Zsh", result.stderr)

    @unittest.skipUnless(ZSH, "Zsh is required")
    def test_install_failure_preserves_environment(self):
        self.executable(self.bin / "python3", "exit 0\n")
        venv_bin = self.root / ".dev-venv" / "bin"
        venv_bin.mkdir(parents=True)
        self.executable(venv_bin / "python", 'if [ "$3" = install ]; then exit 1; fi\nexit 0\n')
        self.executable(venv_bin / "pip", "exit 0\n")
        result = self.run_shell(
            ZSH, 'setopt ERR_EXIT; export VIRTUAL_ENV=original; original_path=$PATH; '
            'source ./activate.sh || print "failed:$?"; '
            '[[ $PATH == $original_path ]] || exit 99; '
            'print "venv:$VIRTUAL_ENV function:${+functions[_dotfiles_dev_activate]}"',
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("failed:1", result.stdout)
        self.assertIn("venv:original function:0", result.stdout)
        self.assertIn("Could not install the dev entrypoint", result.stderr)

    @unittest.skipUnless(ZSH, "Zsh is required")
    def test_local_python_creates_venv_when_system_python_is_too_old(self):
        self.executable(self.bin / "python", "exit 1\n")
        self.executable(self.bin / "python3", "exit 1\n")
        python_bin = self.root / ".dev-python" / "cpython-3.11-test" / "bin"
        python_bin.mkdir(parents=True)
        self.fake_python(python_bin / "python3.11")
        result = self.run_shell(
            ZSH, 'source ./activate.sh || exit 99; print "venv:$VIRTUAL_ENV"',
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.root / ".dev-venv" / "bin" / "python").is_file())
        self.assertIn(f"venv:{self.root}/.dev-venv", result.stdout)

    @unittest.skipUnless(ZSH, "Zsh is required")
    def test_existing_old_venv_is_backed_up_and_replaced(self):
        venv_bin = self.root / ".dev-venv" / "bin"
        venv_bin.mkdir(parents=True)
        self.executable(venv_bin / "python", 'printf "Python 3.9.6\\n"\nexit 1\n')
        self.executable(venv_bin / "pip", "exit 0\n")
        python_bin = self.root / ".dev-python" / "cpython-3.11-test" / "bin"
        python_bin.mkdir(parents=True)
        self.fake_python(python_bin / "python3.11")
        for name in ("mktemp", "mv"):
            (self.bin / name).symlink_to(shutil.which(name))
        result = self.run_shell(ZSH, 'source ./activate.sh || exit 99')
        self.assertEqual(result.returncode, 0, result.stderr)
        backups = list(self.root.glob(".dev-venv-backup.*/venv/bin/python"))
        self.assertEqual(len(backups), 1)
        self.assertIn("Python 3.9.6", backups[0].read_text())
        self.assertIn("Preserved the old virtual environment", result.stdout)
        self.assertNotIn("Python 3.9.6", (venv_bin / "python").read_text())

    @unittest.skipUnless(ZSH, "Zsh is required")
    def test_bootstrap_downloads_python_with_cached_uv(self):
        tools = self.root / ".dev-tools"
        tools.mkdir()
        self.fake_uv(tools / "uv")
        result = self.run_shell(ZSH, 'source ./activate.sh || exit 99')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.root / ".dev-venv" / "bin" / "python").exists())
        self.assertIn("Installing repository-local Python 3.11", result.stdout)

    @unittest.skipUnless(ZSH, "Zsh is required")
    def test_fresh_bootstrap_installs_uv_and_python(self):
        self.fake_uv(self.bin / "mock-uv")
        self.env["MOCK_UV"] = str(self.bin / "mock-uv")
        installer = self.bin / "mock-installer"
        self.executable(
            installer,
            '[ "$UV_NO_MODIFY_PATH" = 1 ] || exit 1\n'
            '[ "$UV_NO_INSTALLER_METADATA" = 1 ] || exit 1\n'
            '/bin/cp "$MOCK_UV" "$UV_INSTALL_DIR/uv"\n',
        )
        self.env["MOCK_UV_INSTALLER"] = str(installer)
        self.executable(self.bin / "curl", '/bin/cat "$MOCK_UV_INSTALLER"\n')
        for name in ("sh", "mkdir"):
            (self.bin / name).symlink_to(shutil.which(name))
        result = self.run_shell(ZSH, 'setopt ERR_EXIT; source ./activate.sh || exit 99')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.root / ".dev-tools" / "uv").exists())
        self.assertTrue((self.root / ".dev-venv" / "bin" / "python").exists())

    @unittest.skipUnless(ZSH, "Zsh is required")
    def test_failed_download_preserves_environment(self):
        self.executable(self.bin / "curl", "exit 22\n")
        for name in ("sh", "mkdir"):
            (self.bin / name).symlink_to(shutil.which(name))
        result = self.run_shell(
            ZSH, 'setopt ERR_EXIT; export VIRTUAL_ENV=original; original_path=$PATH; '
            'source ./activate.sh || print "failed:$?"; '
            '[[ $PATH == $original_path ]] || exit 99; print "venv:$VIRTUAL_ENV"',
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("failed:1", result.stdout)
        self.assertIn("venv:original", result.stdout)
        self.assertIn("Could not install uv", result.stderr)
        self.assertFalse((self.root / ".dev-venv").exists())

    @unittest.skipUnless(ZSH, "Zsh is required")
    def test_existing_venv_activates_without_system_python(self):
        venv_bin = self.root / ".dev-venv" / "bin"
        venv_bin.mkdir(parents=True)
        self.executable(venv_bin / "python", "exit 0\n")
        self.executable(venv_bin / "pip", "exit 0\n")
        result = self.run_shell(
            ZSH, 'setopt ERR_EXIT; source ./activate.sh || exit 99; '
            'print -r -- "venv:$VIRTUAL_ENV" "first:$path[1]"; '
            'source ./activate.sh || exit 99; '
            'print "path_entries:${#path}"',
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(f"venv:{self.root}/.dev-venv", result.stdout)
        self.assertIn(f"first:{venv_bin}", result.stdout)
        self.assertIn("path_entries:2", result.stdout)
