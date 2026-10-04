# Zsh tutorial companion

Read a chapter in your terminal, then run a short demonstration to see commands
and their results together. The reader opens `ch1.md` through `ch5.md` beside this
directory and displays their Markdown as text.

Press `d` for a demonstration. It runs a fixed program from `tui.py`, not the
chapter's code blocks. Chapter 1 uses the context demo. Work through the chapter
examples in a separate shell when you want to try them yourself.

## Run

From the repository root:

```sh
python3 docs/tutorials/zsh/companion/tui.py
python3 docs/tutorials/zsh/companion/tui.py --help
```

The reader opens Chapter 1. Press `2` to read the next chapter, Up or Down to
scroll, and `q` to leave. The complete key list is below.

Use Python 3.9 or newer on macOS or Linux. The reader needs Python's
standard-library `curses` module and a terminal on both stdin and stdout, with a
working `TERM` setting. Demos also need `zsh` on `PATH` and its standard completion
functions. There are no pip packages or project launcher dependencies.

You can also run `python3 /absolute/path/to/companion/tui.py` from another working
directory. Chapter paths resolve relative to the script, not the current
directory. A missing or unreadable chapter shows an error in the reader. Press
`r` after adding or fixing the file. The other chapters and demos remain usable.

## Keys

| Key | Action |
| --- | --- |
| `1` through `5` | Choose a chapter |
| Tab or Right | Next chapter, wrapping after chapter 5 |
| Shift+Tab or Left | Previous chapter, wrapping before chapter 1 |
| Up / Down or `k` / `j` | Scroll one line |
| Page Up / Page Down or `b` / Space | Scroll one screen |
| Home / End or `g` / `G` | Go to the start or end |
| `d` | Run the current chapter's demo and show its source, streams, and status |
| Esc | Return to the chapter |
| `r` | Reload all chapters and return to the current chapter |
| `q` | Quit |

The same scrolling keys work in demo results. Resizing rewraps the text and keeps
the scroll position within its bounds. Below 24 columns or 6 rows, the reader
shows a resize prompt where space permits. Quit and navigation keys still work.

## Headless demos

These commands print the same reports without curses or a terminal:

```sh
python3 docs/tutorials/zsh/companion/tui.py --demo context
python3 docs/tutorials/zsh/companion/tui.py --demo arguments
python3 docs/tutorials/zsh/companion/tui.py --demo execution
python3 docs/tutorials/zsh/companion/tui.py --demo interaction
```

- Context changes a disposable working directory. A child Zsh inherits that
  directory and an exported variable, but not an unexported variable.
- Arguments prints the count and each argument separately, including a filename
  with spaces, a literal wildcard, and an empty argument.
- Execution compares `false | true` with and without `PIPE_FAIL`. It prints both
  the overall pipeline status and each member's status. The demo itself exits
  zero because its final `printf` succeeds. It also emits a separate stderr line.
- Interaction inspects Emacs line-editor bindings, the completion function for
  `cd`, and a completion widget. It loads completion with `compinit -D -i`, which
  skips the completion cache and ignores insecure completion directories. It
  inspects definitions in a noninteractive shell and does not open a nested
  terminal or simulate actual typing or completion.

Each invocation runs an explicit `zsh -f -c` argument list with captured stdout
and stderr, closed stdin, and a five-second timeout. It uses a fresh temporary
working directory, `HOME`, `ZDOTDIR`, and `TMPDIR`, plus a small environment with
the system default command path. It removes those directories after the run.
Timeouts kill the demo's process group, including child processes. No demo reads
or writes your dotfiles. Zsh can still read the machine's global `zshenv` even
with `-f`.

Reports show the exact fixed source and label both output streams, including
empty streams. Control characters in displayed text appear as escapes, so an
escape sequence in output or a chapter cannot act as a terminal command. Tabs
expand to spaces. Headless status is the demo's exit status, or `128 + signal`
if a signal kills it. Status `124` means timeout, `127` means missing Zsh, and
`126` means a launch, temporary-directory, or cleanup error. The reader uses
status `2` for terminal setup errors and `130` for Ctrl+C.

## Check

From the repository root:

```sh
python3 -m unittest discover -s docs/tutorials/zsh/companion -p 'test_*.py'
```

The tests cover chapter lookup from another working directory, missing/read
errors, navigation bounds, wrapping and control characters, the headless CLI,
real Zsh results, temporary-directory cleanup, failures, and timeouts. Tests that
need Zsh skip when it is absent.
