# Python in Neovim

Python buffers use the pinned ALE plugin for **Ruff linting and formatting** and
**Pyright type diagnostics and language intelligence**. The buffer-local linter
list is exactly `ruff`, `pyright`; formatting uses `ruff_format`. Formatting is
explicit by default. Opening or saving a file does not apply fixes.

## Editing

| Action | Keys | Command |
| --- | --- | --- |
| Format current buffer | `<leader>pf` | `:ALEFix` |
| Previous / next diagnostic | `[d` / `]d` | `:ALEPreviousWrap` / `:ALENextWrap` |
| Definition | `gd` | `:ALEGoToDefinition` |
| Hover information | `K` | `:ALEHover` |
| Completion | Insert-mode `Ctrl-X Ctrl-O` | ALE omnifunc |
| Refresh diagnostics | | `:ALELint` |
| Diagnostic detail | | `:ALEDetail` |
| Inspect tools | | `:PythonTools`, `:ALEInfo` |

The leader comes from the core editor configuration (Neovim's default is `\`).
Mappings and `omnifunc=ale#completion#OmniFunc` are local to Python buffers.
Completion is requested explicitly; an automatic completion plugin is not needed.
`:ALEFix` formats the buffer asynchronously; review the result and `:write` to
save. It runs `ruff format`, not `ruff check --fix`, so lint fixes such as removal
of unused imports remain a separate deliberate terminal operation.

## Three independent selections

### Interpreter and imports

ALE's native `ale#python#FindVirtualenv()` searches upward from the buffer for a
virtualenv with a readable activation script. Its default names start with
`.venv`, followed by `env`, `ve`, `venv`, `virtualenv`, `.env`. If none is found,
it uses `$VIRTUAL_ENV`. **A nearby project environment takes precedence over an
activated environment.** Pyright's native ALE callback supplies that environment's
`bin/python` as `python.pythonPath`.

The pinned ALE revision uses Neovim's native LSP transport. It sends its resolved
configuration in a notification, but does not copy it into the native client's
`settings`, which Pyright's `workspace/configuration` requests consult. The
Python module bridges ALE's configuration into that same client's settings on
`ALELSPStarted` and re-notifies Pyright. Interpreter discovery still belongs to
ALE; there is no parallel interpreter registry or separate LSP client.

For an explicit interpreter, set the native ALE option before opening the file:

```vim
let g:ale_python_pyright_config = {'python': {'pythonPath': '/absolute/env/bin/python'}}
```

A `b:ale_python_pyright_config` set before the Python ftplugin runs can scope this
to a buffer. Explicit `pythonPath` is preserved even if another `.venv` is nearby.
Restart Neovim after changing an environment or interpreter selection so the
server and its import caches start fresh.

**Terminal tools do not automatically inherit ALE's interpreter selection.**
For comparable results, activate the same environment or use Pyright's native
`--pythonpath` flag. For example, from the project root:

```sh
python3 -m venv .venv
. .venv/bin/activate
python -c 'import sys; print(sys.executable)'
pyright src/example.py
# Without activation, select the interpreter explicitly:
pyright --pythonpath "$PWD/.venv/bin/python" src/example.py
```

Outside the project root, also pass `--project /absolute/project` to the CLI.
The editor's ALE root detection starts at the buffer, so nested files opened
from an unrelated working directory still find `pyproject.toml` or
`pyrightconfig.json`. For a Ruff-only project using `ruff.toml`, Ruff discovers
its own policy via `--stdin-filename`; ALE's Python root markers do not include
`ruff.toml` alone. Add `pyproject.toml` or `pyrightconfig.json` to define a shared
Pyright project root if needed.

### Checker executable and version

By default, ALE looks for `.venv/bin/ruff` and `.venv/bin/pyright-langserver`
in its selected environment, then uses `ruff` / `pyright-langserver` from PATH.
An activated environment participates through native virtualenv detection and
PATH. The language-server executable is distinct from the interpreter used to
resolve application imports. Ruff itself does not use the Python interpreter.

The harness supplies Ruff **0.16.10**, Pyright **1.1.414**, Python **3.12**,
Neovim **0.12.5**, and Pyright's pinned Node **22.20.0**. Its PATH Pyright wrappers
invoke `/opt/dotfiles/node/bin/node` and code under `/opt/dotfiles/checkers`;
global npm availability is not required. A project-supplied checker can use its
own runtime and version.

Explicit non-default ALE executable options are authoritative:

```vim
let g:ale_python_ruff_executable = '/absolute/tools/ruff'
let g:ale_python_ruff_format_executable = '/absolute/tools/ruff'
let g:ale_python_pyright_executable = '/absolute/tools/pyright-langserver'
```

The module sets the corresponding **buffer-local** `*_use_global` flag only for
these explicit overrides, so a project executable cannot mask an intentionally
selected path. No blanket global-use setting defeats default project discovery.
Lint and formatter executable overrides are separate; set both when selecting
a different Ruff for both operations. Invalid or failing explicitly selected
executables are reported; they are not replaced with another checker.

### Code policy

Ruff reads the project's `pyproject.toml` (`[tool.ruff]`), `ruff.toml`, or
`.ruff.toml` through its normal discovery rules. Pyright reads
`pyrightconfig.json` or `[tool.pyright]` in `pyproject.toml`. No dotfiles-owned
checker policy is forced with a `--config` argument. For example:

```toml
[tool.ruff]
line-length = 40
[tool.ruff.lint]
ignore = ["F401"]
[tool.ruff.format]
quote-style = "single"
[tool.pyright]
reportAssignmentType = "none"
```

This changes actual diagnostics and formatting in the editor and CLI without
changing which checker or Python interpreter is selected.

## Inspection and disabling

`:PythonTools` warns about unavailable executables and failed commands in ALE's
bounded command history. Ruff exit 1 means lint findings, not infrastructure
failure; exits above 1 are reported as failures. The same inspection runs on
Python setup and `ALELintPost`. Older failed jobs can remain in the history;
inspect the latest job in `:ALEInfo`. For captured stderr, enable
`let g:ale_history_log_output = 1` before running the checker. LSP startup errors
and unsupported operations should also be inspected in `:ALEInfo` and
`:messages`; an empty diagnostic list alone does not establish checker success.

Useful native resolution queries:

```vim
:echo ale#python#FindVirtualenv(bufnr(''))
:echo ale_linters#python#pyright#GetConfig(bufnr(''))
:echo ale_linters#python#pyright#GetExecutable(bufnr(''))
:echo ale_linters#python#ruff#GetExecutable(bufnr(''))
:echo ale#fixers#ruff_format#GetExecutable(bufnr(''))
```

`:ALEDisableBuffer` / `:ALEEnableBuffer` disable/enable diagnostics for the current
buffer. `let b:ale_enabled = 0` before filetype setup also works and suppresses
tool warnings. `:ALEDisable` disables linting globally. Formatting is a separate
explicit action. To enable format-on-save intentionally, set
`let b:ale_fix_on_save = 1` after Python setup.

## Fixture evidence and integration

`tests/test_python.py` boots actual Neovim with the recorded ALE checkout and a
temporary init that adds `nvim`, `nvim/after`, and ALE to runtimepath and enables
filetype plugins. The real after-ftplugin loads the module. All projects, homes,
venvs, marker packages, and scripts are generated under pytest temporary dirs.
There are no pip downloads. The tests verify:

- Default `F401`, a real Pyright assignment mismatch, and completed Ruff formatting.
- A real ALE definition jump and the ALE omnifunc selection.
- Ruff ignore, line length, and quote style; Pyright assignment policy in both
  TOML and JSON; nested files opened outside the project root.
- Project, activated, and explicit interpreters using a local typed package
  installed only in the selected venv's `sysconfig` site-packages. CLI activation
  or `--pythonpath` agrees with ALE outcomes and native client settings.
- Real project Ruff forwarding, version and command markers, formatter execution,
  and authoritative executable overrides.
- Disable behavior and unavailable/failing explicit Ruff selections, including
  proof that a competing project checker was not silently run.

Run the full pinned harness:

```sh
docker run --rm --platform linux/arm64 --user vscode \
  -v "$PWD:/workspace" -w /workspace dotfiles-m1:baseline make test
```

This step depends on the step 1 harness (PR #14, `27e4e13`). The combined user
configuration also needs sibling step 5 to load pinned ALE at startup and put
the configuration root and its `after` directory on runtimepath. The standalone
tests deliberately supply this bootstrap because this base has no `init.lua`.
After those changes are combined, manually open a project Python buffer with
the normal startup, check `:ALEInfo`, request `Ctrl-X Ctrl-O` completion and hover,
follow a definition, navigate diagnostics, and review explicit formatting.
Interactive completion/hover and the combined normal startup remain integration
checks; the headless fixture results do not claim GUI or provider coverage.
