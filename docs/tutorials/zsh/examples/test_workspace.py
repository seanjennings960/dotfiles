import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


HELPER = Path(__file__).resolve().with_name("workspace.zsh")
ZSH = shutil.which("zsh")


@unittest.skipUnless(ZSH, "Zsh is required for the workspace example")
class WorkspaceTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="zsh-workspace-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.home = self.root / "home"
        self.home.mkdir()
        self.state = self.root / "state with spaces"
        self.project = self.root / "project with spaces"
        self.project.mkdir()
        self.env = {
            "PATH": os.defpath,
            "HOME": str(self.home),
            "ZDOTDIR": str(self.home),
            "WS_HOME": str(self.state),
            "LC_ALL": "C",
        }

    def run_zsh(self, code, *args, env=None):
        return subprocess.run(
            [ZSH, "-f", "-c", 'source "$1" || exit; shift\n' + code,
             "workspace-test", str(HELPER), *map(str, args)],
            cwd=self.home,
            env=self.env if env is None else env,
            capture_output=True,
            text=True,
            timeout=10,
        )

    def add_project(self, name="demo", project=None):
        result = self.run_zsh('ws add "$1" "$2"', name, project or self.project)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_sourcing_is_repeatable_and_does_not_create_state(self):
        result = self.run_zsh(
            'setopt shwordsplit\nsource "$1"\n'
            '[[ -o shwordsplit ]] || exit 9\nws help', HELPER)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("ws add NAME DIRECTORY", result.stdout)
        self.assertFalse(self.state.exists())

    def test_add_list_and_go_preserve_exact_path(self):
        self.add_project()
        self.assertEqual((self.state / "demo").read_bytes(),
                         os.fsencode(self.project) + b"\0")
        listing = self.run_zsh("ws")
        self.assertEqual(listing.returncode, 0, listing.stderr)
        self.assertIn("demo\t", listing.stdout)
        self.assertIn(r"project\ with\ spaces", listing.stdout)
        visit = self.run_zsh('ws go demo || exit\nprint -rn -- "$PWD"')
        self.assertEqual(visit.returncode, 0, visit.stderr)
        self.assertEqual(visit.stdout, str(self.project))

    def test_newlines_and_leading_hyphens_survive_storage(self):
        project = self.root / "-project\nwith a trailing newline\n"
        project.mkdir()
        self.add_project("-demo", project)
        self.assertEqual((self.state / "-demo").read_bytes(),
                         os.fsencode(project) + b"\0")
        result = self.run_zsh('ws go -demo || exit\nprint -rn -- "$PWD"')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, str(project))

    def test_subshell_selection_does_not_change_parent(self):
        self.add_project()
        result = self.run_zsh('( ws go demo && pwd )\npwd')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), [str(self.project), str(self.home)])

    def test_bad_names_and_argument_counts_return_usage_status(self):
        for name in ("", "..", ".hidden", "a/b", "two words", "x\ny", "café"):
            with self.subTest(name=name):
                result = self.run_zsh('ws add "$1" "$2"', name, self.project)
                self.assertEqual(result.returncode, 2, result.stderr)
        for code in ("ws go", "ws add demo", "ws list extra", "ws help extra",
                     "ws unknown", "ws add demo . extra"):
            with self.subTest(code=code):
                self.assertEqual(self.run_zsh(code).returncode, 2)
        self.assertFalse(self.state.exists())

    def test_empty_registry_lists_successfully_without_creating_it(self):
        result = self.run_zsh("ws list")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "")
        self.assertFalse(self.state.exists())

    def test_missing_directory_does_not_replace_existing_record(self):
        self.add_project()
        before = (self.state / "demo").read_bytes()
        result = self.run_zsh('ws add demo "$1"', self.root / "missing")
        self.assertEqual(result.returncode, 1)
        self.assertEqual((self.state / "demo").read_bytes(), before)
        self.assertEqual(list(self.state.iterdir()), [self.state / "demo"])

    def test_unknown_and_missing_targets_preserve_cwd(self):
        self.add_project()
        self.project.rmdir()
        for name in ("unknown", "demo"):
            with self.subTest(name=name):
                result = self.run_zsh(
                    'if ws go "$1"; then exit 9; fi\nprint -rn -- "$PWD"', name)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, str(self.home))
                self.assertTrue(result.stderr)

    def test_malformed_records_fail_without_changing_directory(self):
        self.state.mkdir()
        for contents in (b"", os.fsencode(self.project), b"relative\0", b"\0",
                         os.fsencode(self.project) + b"\0junk",
                         os.fsencode(self.project) + b"\0\0"):
            with self.subTest(contents=contents):
                (self.state / "bad").write_bytes(contents)
                result = self.run_zsh(
                    'if ws go bad; then exit 9; fi\nprint -rn -- "$PWD"')
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, str(self.home))
                self.assertNotEqual(self.run_zsh("ws list").returncode, 0)

    def test_symlink_records_and_directories_are_not_selected(self):
        self.add_project()
        (self.state / "link").symlink_to(self.state / "demo")
        (self.state / "directory").mkdir()
        (self.state / ".tmp.unfinished").write_bytes(b"unfinished")
        (self.state / "invalid name").write_bytes(b"invalid")
        result = self.run_zsh("ws list")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(result.stdout.splitlines()), 1)
        for name in ("link", "directory"):
            self.assertNotEqual(self.run_zsh('ws go "$1"', name).returncode, 0)

    def test_failed_rename_preserves_record_and_cleans_temp_file(self):
        self.add_project()
        before = (self.state / "demo").read_bytes()
        other = self.root / "other"
        other.mkdir()
        binaries = self.root / "bin"
        binaries.mkdir()
        failing_mv = binaries / "mv"
        failing_mv.write_text("#!/bin/sh\nexit 17\n", encoding="utf-8")
        failing_mv.chmod(0o755)
        env = dict(self.env, PATH=str(binaries) + os.pathsep + os.defpath)
        result = self.run_zsh('ws add demo "$1"', other, env=env)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual((self.state / "demo").read_bytes(), before)
        self.assertEqual(list(self.state.iterdir()), [self.state / "demo"])

    def test_directory_collision_does_not_receive_temporary_record(self):
        (self.state / "demo").mkdir(parents=True)
        result = self.run_zsh('ws add demo "$1"', self.project)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(list((self.state / "demo").iterdir()), [])
        self.assertEqual(list(self.state.iterdir()), [self.state / "demo"])

    def test_xdg_and_home_fallbacks_use_expected_locations(self):
        env = self.env.copy()
        del env["WS_HOME"]
        env["XDG_STATE_HOME"] = str(self.root / "xdg state")
        result = self.run_zsh('ws add demo "$1"', self.project, env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((Path(env["XDG_STATE_HOME"]) /
                         "zsh-tutorial/workspaces/demo").is_file())
        del env["XDG_STATE_HOME"]
        result = self.run_zsh('ws add demo "$1"', self.project, env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.home / ".local/state/zsh-tutorial/workspaces/demo").is_file())

    def test_relative_state_path_is_rejected(self):
        result = self.run_zsh('ws add demo "$1"', self.project,
                              env=dict(self.env, WS_HOME="relative"))
        self.assertEqual(result.returncode, 2)
        self.assertFalse((self.home / "relative").exists())

    def test_caller_options_are_restored_after_success_and_failure(self):
        self.add_project()
        result = self.run_zsh(
            'setopt shwordsplit nullglob\n'
            'ws go demo || exit\n'
            '[[ -o shwordsplit && -o nullglob ]] || exit 8\n'
            'if ws go unknown; then exit 9; fi\n'
            '[[ -o shwordsplit && -o nullglob ]]')
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
