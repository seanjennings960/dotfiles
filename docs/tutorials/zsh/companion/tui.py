#!/usr/bin/env python3
"""A chapter reader with four fixed Zsh demonstrations. Python 3.9+, stdlib only."""

import argparse
from dataclasses import dataclass
import os
from pathlib import Path
import shlex
import shutil
import signal
import subprocess
import sys
import tempfile
from typing import List, Optional
import unicodedata

try:
    import curses
except ImportError:
    curses = None


CHAPTER_DIR = Path(__file__).resolve().parent.parent
CHAPTERS = (
    ("ch1.md", "Basics", "context"),
    ("ch2.md", "Context", "context"),
    ("ch3.md", "Arguments", "arguments"),
    ("ch4.md", "Execution", "execution"),
    ("ch5.md", "Interaction", "interaction"),
)
DEMO_TIMEOUT = 5.0

# These are the only programs the application executes. Chapter text is data.
DEMOS = {
    "context": r'''printf 'Starting directory: %s\n' "$PWD"
printf 'Disposable HOME: %s\n' "$HOME"
mkdir project || exit
cd project || exit
printf 'After cd: %s\n' "$PWD"
local_only='only this shell'
export TUTORIAL_EXPORTED='visible to children'
"$ZSH_TUTORIAL_ZSH" -f -c '
  printf "Child directory: %s\n" "$PWD"
  printf "Child exported value: %s\n" "$TUTORIAL_EXPORTED"
  printf "Child unexported value: %s\n" "${local_only-unset}"
'
''',
    "arguments": r'''show_argv() {
  printf 'argc=%s\n' "$#"
  local arg
  local -i index=1
  for arg in "$@"; do
    printf 'argv[%d]=<%s>\n' "$index" "$arg"
    (( index += 1 ))
  done
}
args=('notes.txt' 'my notes.txt' '*.txt' '')
show_argv "${args[@]}"
''',
    "execution": r'''unsetopt PIPE_FAIL
false | true
printf 'Default: pipeline=%s members=%s\n' "$?" "${(j:,:)pipestatus}"
setopt PIPE_FAIL
false | true
printf 'PIPE_FAIL: pipeline=%s members=%s\n' "$?" "${(j:,:)pipestatus}"
printf 'This diagnostic goes to stderr.\n' >&2
printf 'The final printf succeeds, so the demo exits 0.\n'
''',
    "interaction": r'''autoload -Uz compinit
compinit -D -i || exit
bindkey -e
printf 'Emacs Ctrl+A binding:\n'
bindkey -M emacs '^A'
printf 'Emacs Tab binding:\n'
bindkey -M emacs '^I'
printf 'Completion function for cd: %s\n' "${_comps[cd]-unset}"
printf 'Completion widget definition:\n'
zle -l -L expand-or-complete
''',
}


def read_chapters() -> List[str]:
    chapters = []
    for filename, title, _ in CHAPTERS:
        path = CHAPTER_DIR / filename
        try:
            chapters.append(path.read_text(encoding="utf-8", errors="replace"))
        except FileNotFoundError:
            chapters.append(
                f"# {title}\n\nChapter file is missing: {path}\n\n"
                "Press r to reload after the chapter is available. "
                "Press d to run its demo."
            )
        except OSError as exc:
            chapters.append(f"# {title}\n\nCannot read {path}: {exc}\n\nPress r to retry.")
    return chapters


@dataclass
class DemoResult:
    concept: str
    source: str
    executable: str = "zsh"
    cwd: Optional[str] = None
    home: Optional[str] = None
    stdout: str = ""
    stderr: str = ""
    returncode: Optional[int] = None
    status: int = 0
    error: str = ""


def kill_demo(process: subprocess.Popen) -> None:
    """Kill the demo's private process group, including pipeline/child processes."""
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass


def run_demo(concept: str, timeout: float = DEMO_TIMEOUT) -> DemoResult:
    result = DemoResult(concept, DEMOS[concept])
    executable = shutil.which("zsh")
    if executable is None:
        result.status = 127
        result.error = "Zsh was not found on PATH. Install Zsh to run demos."
        return result
    result.executable = os.path.abspath(executable)
    try:
        with tempfile.TemporaryDirectory(prefix="zsh-tutorial-") as directory:
            root = Path(directory).resolve()
            work, home, temp = root / "work", root / "home", root / "tmp"
            for path in (work, home, temp):
                path.mkdir()
            result.cwd, result.home = str(work), str(home)
            # Do not inherit shell startup settings, exported functions, or HOME.
            env = {
                "PATH": os.defpath,
                "HOME": str(home),
                "ZDOTDIR": str(home),
                "TMPDIR": str(temp),
                "LC_ALL": "C",
                "TERM": "dumb",
                "ZSH_TUTORIAL_ZSH": result.executable,
            }
            with subprocess.Popen(
                [result.executable, "-f", "-c", result.source, "zsh-tutorial-demo"],
                cwd=work,
                env=env,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                encoding="utf-8",
                errors="replace",
                start_new_session=True,
            ) as process:
                try:
                    result.stdout, result.stderr = process.communicate(timeout=timeout)
                except subprocess.TimeoutExpired:
                    kill_demo(process)
                    result.stdout, result.stderr = process.communicate()
                    result.status = 124
                    result.error = f"Demo timed out after {timeout:g} seconds."
                except BaseException:
                    kill_demo(process)
                    process.communicate()
                    raise
                result.returncode = process.returncode
                if not result.error:
                    result.status = (
                        process.returncode if process.returncode >= 0
                        else 128 - process.returncode
                    )
    except OSError as exc:
        result.status = 126
        result.error = f"Cannot run demo or clean up its temporary directory: {exc}"
    return result


def format_demo(result: DemoResult) -> str:
    return (
        f"# {result.concept.capitalize()} demo\n\n"
        f"Command: {shlex.quote(result.executable)} -f -c <source below> zsh-tutorial-demo\n"
        f"Working directory: {result.cwd or '(not started)'}\n"
        f"HOME: {result.home or '(not started)'}\n"
        "Each run uses a fresh temporary directory; cleanup runs after the demo.\n\n"
        f"Source, passed literally to Zsh:\n{result.source}\n"
        f"stdout:\n{result.stdout or '(empty)'}\n"
        f"stderr:\n{result.stderr or '(empty)'}\n"
        f"Exit status: {result.status}\n"
        f"Zsh return code: {result.returncode if result.returncode is not None else '(not started)'}\n"
        + (f"Error: {result.error}\n" if result.error else "")
    )


def visible_text(text: str) -> str:
    """Show escape/control characters as text, including bidi format controls."""
    return "".join(
        char if char in "\n\t" or char.isprintable() else ascii(char)[1:-1]
        for char in text
    ).expandtabs(4)


def wrap_text(text: str, width: int) -> List[str]:
    """Hard-wrap plain text by terminal cells; retain indentation and blank lines."""
    width = max(1, width)
    lines = []
    for line in visible_text(text).split("\n"):
        current, cells = [], 0
        for char in line:
            size = 0 if unicodedata.combining(char) else (
                2 if unicodedata.east_asian_width(char) in "WF" else 1
            )
            if size > width:
                char, size = "?", 1
            if current and cells + size > width:
                lines.append("".join(current))
                current, cells = [], 0
            current.append(char)
            cells += size
        lines.append("".join(current))
    return lines


@dataclass
class Reader:
    chapters: List[str]
    chapter: int = 0
    offset: int = 0
    demo: Optional[DemoResult] = None

    def select(self, chapter: int) -> None:
        self.chapter = chapter % len(CHAPTERS)
        self.offset = 0
        self.demo = None

    def scroll(self, delta: int, line_count: int, rows: int) -> None:
        last = max(0, line_count - max(1, rows))
        self.offset = min(last, max(0, self.offset + delta))

    def text(self) -> str:
        return format_demo(self.demo) if self.demo else self.chapters[self.chapter]


def write_line(screen, row: int, text: str, attr: int = 0) -> None:
    height, width = screen.getmaxyx()
    if row < 0 or row >= height or width < 2:
        return
    try:
        screen.addstr(row, 0, wrap_text(text, width - 1)[0], attr)
    except curses.error:
        # A resize can occur between measuring the window and drawing a line.
        pass


def draw(screen, reader: Reader, notice: str = ""):
    screen.erase()
    height, width = screen.getmaxyx()
    lines = wrap_text(reader.text(), width - 1)
    rows = max(1, height - 4)
    reader.scroll(0, len(lines), rows)
    if height < 6 or width < 24:
        write_line(screen, 0, "Terminal too small")
        write_line(screen, 1, "Resize; q quit")
    else:
        mode = "demo" if reader.demo else "chapter"
        write_line(screen, 0, f"Zsh tutorial | {reader.chapter + 1}. "
                   f"{CHAPTERS[reader.chapter][1]} | {mode}", curses.A_BOLD)
        write_line(screen, 1, "1 Basics | 2 Context | 3 Arguments | 4 Execution | 5 Interaction")
        for row, line in enumerate(lines[reader.offset:reader.offset + rows], 2):
            write_line(screen, row, line)
        write_line(screen, height - 2, notice or (
            "d demo | Esc chapter | r reload | "
            f"Lines {reader.offset + 1}-{min(len(lines), reader.offset + rows)}/{len(lines)}"
        ))
        write_line(screen, height - 1,
                   "q quit | 1-5/Tab/Left/Right chapter | Up/Down/PgUp/PgDn scroll")
    try:
        screen.refresh()
    except curses.error:
        pass
    return len(lines), rows


def run_ui(screen) -> None:
    screen.keypad(True)
    try:
        curses.curs_set(0)
    except curses.error:
        pass
    curses.set_escdelay(25)
    reader = Reader(read_chapters())
    while True:
        line_count, rows = draw(screen, reader)
        try:
            key = screen.get_wch()
        except curses.error:
            continue
        if key in ("q", "Q"):
            return
        if isinstance(key, str) and key in "12345":
            reader.select(int(key) - 1)
        elif key in ("\t", curses.KEY_RIGHT):
            reader.select(reader.chapter + 1)
        elif key in (curses.KEY_BTAB, curses.KEY_LEFT):
            reader.select(reader.chapter - 1)
        elif key in ("j", curses.KEY_DOWN):
            reader.scroll(1, line_count, rows)
        elif key in ("k", curses.KEY_UP):
            reader.scroll(-1, line_count, rows)
        elif key in (" ", curses.KEY_NPAGE):
            reader.scroll(rows, line_count, rows)
        elif key in ("b", curses.KEY_PPAGE):
            reader.scroll(-rows, line_count, rows)
        elif key in ("g", curses.KEY_HOME):
            reader.offset = 0
        elif key in ("G", curses.KEY_END):
            reader.scroll(line_count, line_count, rows)
        elif key == "\x1b":
            reader.select(reader.chapter)
        elif key == "r":
            reader.chapters = read_chapters()
            reader.select(reader.chapter)
        elif key == "d":
            concept = CHAPTERS[reader.chapter][2]
            draw(screen, reader, f"Running {concept} demo, {DEMO_TIMEOUT:g}s timeout...")
            reader.demo = run_demo(concept)
            reader.offset = 0
        # KEY_RESIZE needs only a redraw. Rewrapping also clamps the offset.


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="Read five Zsh chapters and run fixed, isolated Zsh demos.",
        epilog="Reader keys: 1-5 or Tab/Left/Right choose a chapter; Up/Down and "
               "PgUp/PgDn scroll; d runs a demo; Esc returns; r reloads; q quits.",
    )
    parser.add_argument("--demo", choices=tuple(DEMOS),
                        help="print demo source, stdout, stderr, and status without a TTY")
    args = parser.parse_args(argv)
    try:
        if args.demo:
            result = run_demo(args.demo)
            print(visible_text(format_demo(result)))
            return result.status
        if not sys.stdin.isatty() or not sys.stdout.isatty():
            print("The reader needs a TTY on stdin and stdout. "
                  "Use --demo context or --help for headless use.", file=sys.stderr)
            return 2
        if curses is None:
            print("The reader needs Python's standard-library curses module. "
                  "Use --demo for headless use.", file=sys.stderr)
            return 2
        if os.environ.get("TERM", "") in ("", "dumb", "unknown"):
            print("The reader needs a terminal with a usable TERM value. "
                  "Use --demo for headless use.", file=sys.stderr)
            return 2
        try:
            curses.wrapper(run_ui)
        except curses.error as exc:
            print(f"Cannot use the terminal: {visible_text(str(exc))}", file=sys.stderr)
            return 2
    except KeyboardInterrupt:
        return 130
    except BrokenPipeError:
        return 1
    except OSError as exc:
        print(f"Reader error: {visible_text(str(exc))}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
