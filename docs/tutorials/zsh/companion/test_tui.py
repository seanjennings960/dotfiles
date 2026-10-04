import contextlib
import io
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

import tui


class ChapterTests(unittest.TestCase):
    def test_lookup_from_unrelated_cwd(self):
        original = Path.cwd()
        expected = (tui.CHAPTER_DIR / "ch1.md").read_text(encoding="utf-8")
        with tempfile.TemporaryDirectory() as directory:
            try:
                os.chdir(directory)
                chapters = tui.read_chapters()
            finally:
                os.chdir(original)
        self.assertEqual(len(chapters), 5)
        self.assertEqual(chapters[0], expected)
        self.assertIn("# Chapter 1", chapters[0])

    def test_missing_chapters_can_be_reloaded(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with mock.patch.object(tui, "CHAPTER_DIR", root):
                chapters = tui.read_chapters()
                self.assertIn(f"Chapter file is missing: {root / 'ch2.md'}", chapters[1])
                self.assertIn("Press r", chapters[1])
                (root / "ch2.md").write_text("# Context\nnew chapter\n", encoding="utf-8")
                self.assertEqual(tui.read_chapters()[1], "# Context\nnew chapter\n")

    def test_read_errors_are_content(self):
        with mock.patch.object(Path, "read_text", side_effect=PermissionError("denied")):
            chapters = tui.read_chapters()
        self.assertTrue(all("Cannot read" in chapter and "denied" in chapter
                            for chapter in chapters))


class ReaderTests(unittest.TestCase):
    def test_chapter_navigation_wraps_and_leaves_demo(self):
        reader = tui.Reader([str(i) for i in range(5)], offset=50,
                            demo=tui.DemoResult("context", ""))
        reader.select(-1)
        self.assertEqual(reader.chapter, 4)
        self.assertEqual(reader.offset, 0)
        self.assertIsNone(reader.demo)
        self.assertEqual(reader.text(), "4")
        reader.select(5)
        self.assertEqual(reader.chapter, 0)

    def test_scroll_clamps_after_resize_and_for_short_content(self):
        reader = tui.Reader([""] * 5)
        reader.scroll(1000, 100, 10)
        self.assertEqual(reader.offset, 90)
        reader.scroll(0, 30, 20)
        self.assertEqual(reader.offset, 10)
        reader.scroll(-100, 30, 20)
        self.assertEqual(reader.offset, 0)
        reader.scroll(100, 3, 10)
        self.assertEqual(reader.offset, 0)
        reader.scroll(100, 3, 0)
        self.assertEqual(reader.offset, 2)

    def test_wrapping_preserves_indentation_and_blank_lines(self):
        self.assertEqual(tui.wrap_text("  abcdef\n\nx", 4), ["  ab", "cdef", "", "x"])
        self.assertEqual(tui.wrap_text("abc", 0), ["a", "b", "c"])

    def test_wide_and_combining_characters_use_terminal_cells(self):
        self.assertEqual(tui.wrap_text("a界b", 3), ["a界", "b"])
        self.assertEqual(tui.wrap_text("e\u0301xy", 2), ["e\u0301x", "y"])
        self.assertEqual(tui.wrap_text("界", 1), ["?"])

    def test_control_characters_cannot_reach_terminal(self):
        text = "ok\x1b]2;title\x07\r\x00\x7f\x9b\u202e\n\tx"
        visible = tui.visible_text(text)
        self.assertEqual(visible, r"ok\x1b]2;title\x07\r\x00\x7f\x9b\u202e" + "\n    x")
        self.assertNotIn("\x1b", "\n".join(tui.wrap_text(text, 10)))


class DemoErrorTests(unittest.TestCase):
    def test_missing_zsh_has_source_and_nonzero_status(self):
        with mock.patch.object(tui.shutil, "which", return_value=None):
            result = tui.run_demo("context")
        self.assertEqual(result.status, 127)
        self.assertIsNone(result.returncode)
        self.assertIsNone(result.cwd)
        report = tui.format_demo(result)
        self.assertIn(tui.DEMOS["context"], report)
        self.assertIn("Zsh was not found", report)

    def test_launch_failure_cleans_up(self):
        with mock.patch.object(tui.shutil, "which", return_value="/missing/tutorial-zsh"):
            result = tui.run_demo("context")
        self.assertEqual(result.status, 126)
        self.assertIn("Cannot run demo", result.error)
        self.assertFalse(Path(result.cwd).parent.exists())

    def test_temp_creation_error(self):
        with mock.patch.object(tui.shutil, "which", return_value="/bin/zsh"), \
                mock.patch.object(tui.tempfile, "TemporaryDirectory",
                                  side_effect=PermissionError("no temporary space")):
            result = tui.run_demo("context")
        self.assertEqual(result.status, 126)
        self.assertIn("no temporary space", result.error)

    def test_only_named_demos_are_accepted(self):
        with mock.patch.object(tui.subprocess, "Popen") as popen:
            with self.assertRaises(KeyError):
                tui.run_demo("printf arbitrary-code")
            popen.assert_not_called()


@unittest.skipUnless(shutil.which("zsh"), "Zsh is required for real demo tests")
class RealDemoTests(unittest.TestCase):
    def test_all_curated_demo_outputs(self):
        expected = {
            "context": ["Child exported value: visible to children",
                        "Child unexported value: unset"],
            "arguments": ["argc=4", "argv[1]=<notes.txt>", "argv[2]=<my notes.txt>",
                          "argv[3]=<*.txt>", "argv[4]=<>"],
            "execution": ["Default: pipeline=0 members=1,0",
                          "PIPE_FAIL: pipeline=1 members=1,0"],
            "interaction": ['"^A" beginning-of-line', '"^I" expand-or-complete',
                            "Completion function for cd: _cd",
                            "zle -C expand-or-complete .expand-or-complete _main_complete"],
        }
        for concept, fragments in expected.items():
            with self.subTest(concept=concept):
                result = tui.run_demo(concept)
                self.assertEqual(result.status, 0, tui.format_demo(result))
                self.assertEqual(result.returncode, 0)
                for fragment in fragments:
                    self.assertIn(fragment, result.stdout)
                self.assertEqual(result.stderr, "This diagnostic goes to stderr.\n"
                                 if concept == "execution" else "")
                self.assertIn(tui.DEMOS[concept], tui.format_demo(result))
                self.assertFalse(Path(result.cwd).parent.exists())

    def test_fresh_home_and_cwd_are_isolated_and_removed(self):
        original_cwd, original_home = Path.cwd(), os.environ.get("HOME")
        first = tui.run_demo("context")
        second = tui.run_demo("context")
        self.assertEqual(first.status, 0)
        self.assertEqual(second.status, 0)
        self.assertNotEqual(first.cwd, second.cwd)
        self.assertNotEqual(first.home, second.home)
        self.assertEqual(Path(first.cwd).parent, Path(first.home).parent)
        self.assertIn(f"Starting directory: {first.cwd}\n", first.stdout)
        self.assertIn(f"Disposable HOME: {first.home}\n", first.stdout)
        self.assertIn(f"After cd: {first.cwd}/project\n", first.stdout)
        self.assertIn(f"Child directory: {first.cwd}/project\n", first.stdout)
        for result in (first, second):
            self.assertFalse(Path(result.cwd).parent.exists())
            self.assertFalse(Path(result.home).exists())
        self.assertEqual(Path.cwd(), original_cwd)
        self.assertEqual(os.environ.get("HOME"), original_home)

    def test_inherited_environment_and_dotfiles_are_not_used(self):
        # Override the internal source only in tests to inspect the child environment.
        source = r'''printf '%s\n' "${TUTORIAL_LEAK-unset}" "$HOME" "$ZDOTDIR" "$TMPDIR"
printf marker > "$HOME/test-dotfile"
'''
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            dotfile = root / ".zshenv"
            dotfile.write_text("print WRONG-STARTUP\n", encoding="utf-8")
            with mock.patch.dict(os.environ, {"HOME": directory, "ZDOTDIR": directory,
                                              "TUTORIAL_LEAK": "secret"}), \
                    mock.patch.dict(tui.DEMOS, {"context": source}):
                result = tui.run_demo("context")
            self.assertEqual(result.status, 0, result.error)
            self.assertEqual(result.stdout.splitlines(),
                             ["unset", result.home, result.home,
                              str(Path(result.home).parent / "tmp")])
            self.assertEqual(list(root.iterdir()), [dotfile])
            self.assertEqual(dotfile.read_text(encoding="utf-8"), "print WRONG-STARTUP\n")
        self.assertFalse(Path(result.home).parent.exists())

    def test_failure_captures_both_streams_and_status(self):
        with mock.patch.dict(tui.DEMOS, {"context": "printf out; printf err >&2; exit 7\n"}):
            result = tui.run_demo("context")
        self.assertEqual((result.stdout, result.stderr, result.returncode, result.status),
                         ("out", "err", 7, 7))
        self.assertFalse(Path(result.cwd).parent.exists())

    def test_signal_exit_has_shell_style_status(self):
        with mock.patch.dict(tui.DEMOS, {"context": "kill -TERM $$\n"}):
            result = tui.run_demo("context")
        self.assertEqual(result.returncode, -15)
        self.assertEqual(result.status, 143)
        self.assertFalse(Path(result.cwd).parent.exists())

    def test_timeout_preserves_output_and_removes_temp_directory(self):
        # Keep a child holding the output pipes open, rather than execing sleep.
        source = "printf ready; printf waiting >&2; sleep 30 &\nwait\n"
        with mock.patch.dict(tui.DEMOS, {"context": source}):
            result = tui.run_demo("context", timeout=0.5)
        self.assertEqual(result.status, 124)
        self.assertEqual(result.returncode, -9)
        self.assertEqual((result.stdout, result.stderr), ("ready", "waiting"))
        self.assertIn("timed out", result.error)
        self.assertFalse(Path(result.cwd).parent.exists())


class CommandLineTests(unittest.TestCase):
    def invoke(self, *args):
        return subprocess.run([sys.executable, str(Path(tui.__file__).resolve()), *args],
                              stdin=subprocess.DEVNULL, capture_output=True,
                              text=True, timeout=10)

    def test_help_without_tty(self):
        result = self.invoke("--help")
        self.assertEqual(result.returncode, 0)
        self.assertIn("--demo {context,arguments,execution,interaction}", result.stdout)

    def test_non_tty_reader_has_clear_error(self):
        result = self.invoke()
        self.assertEqual(result.returncode, 2)
        self.assertIn("needs a TTY", result.stderr)
        self.assertNotIn("Traceback", result.stderr)

    def test_arbitrary_code_is_not_a_cli_option(self):
        result = self.invoke("--demo", "print arbitrary-code")
        self.assertEqual(result.returncode, 2)
        self.assertIn("invalid choice", result.stderr)

    @unittest.skipUnless(shutil.which("zsh"), "Zsh is required for headless demos")
    def test_actual_headless_report(self):
        result = self.invoke("--demo", "arguments")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(tui.DEMOS["arguments"], result.stdout)
        self.assertIn("argv[2]=<my notes.txt>", result.stdout)
        self.assertIn("stdout:\n", result.stdout)
        self.assertIn("stderr:\n(empty)", result.stdout)
        self.assertIn("Exit status: 0", result.stdout)

    def test_headless_propagates_errors_and_escapes_controls(self):
        for status in (7, 124, 126, 127, 143):
            with self.subTest(status=status):
                result = tui.DemoResult("context", tui.DEMOS["context"],
                                        stdout="\x1b[31m", status=status, error="test error")
                output = io.StringIO()
                with mock.patch.object(tui, "run_demo", return_value=result), \
                        contextlib.redirect_stdout(output):
                    self.assertEqual(tui.main(["--demo", "context"]), status)
                self.assertIn(r"\x1b[31m", output.getvalue())
                self.assertNotIn("\x1b", output.getvalue())


if __name__ == "__main__":
    unittest.main()
