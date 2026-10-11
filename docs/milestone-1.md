# Reliable inspection and execution baseline

This integrates milestone 1 of the [roadmap](project.md) on top of the
comprehension-driven architecture in PR #42. The implementation targets Ubuntu
24.04 ARM64 as non-root `vscode`, with real applications and terminal input.

## Source PR accounting

| Source | Integrated contribution |
| --- | --- |
| #14, #15, #6 and the #25–38 consolidation | Worktree discovery, private launcher runtime, faithful exec, metadata-based tmux reconnection, offline transactional activation, locked tests, GitHub PR guidance |
| #16 and overlapping #9 | Bash/Zsh startup and completion, project PATH precedence, failed `cd` status, pane-local logical paths; optional Juliaup PATH appended idempotently |
| #17 and #19 | One production Neovim startup, recorded plugins, native EditorConfig, recoverable state, Ruff/Pyright, and the ALE/native-client settings bridge |
| #18 and overlapping #3/#8 | Attached tmux keys, concurrent logical-path splits/windows, OSC52 emission; stable-ID window moves added here |
| #40–41 | Local container context and reusable personal Feature, expanded here to package the complete baseline |
| This integration | `dev languages`, `:DevLanguages`, missing/disabled/failing selections, normal-startup acceptance, attached window-pop/reconnect tests, packaged installed verification |

Existing implementations were reconciled rather than merging their superseded
roadmaps. The architecture and later comprehension milestones retain PR #42's
contracts. Learning material and agent transcript work remain separate slices.

## Installed layout and contracts

- The Feature installs source/defaults/plugins under `/opt/dotfiles-dev/source`,
  its private Python under `/opt/dotfiles-dev/venv`, and an isolated-import wrapper
  at `/usr/local/bin/dev`. No project Python or import setting selects this runtime.
- `Workspace.root` is canonical identity; each Git worktree is distinct.
  `Workspace.cwd` preserves the invocation directory inside that workspace.
  `--workspace` explicitly overrides discovery. Unreachable mounted worktree Git
  metadata is reported while retaining the worktree boundary.
- `Local(environment)` discovers tmux sessions through `@dev_workspace` and
  `@dev_environment` on the `dotfiles-dev` server. `DEV_ENVIRONMENT` selects local
  `host` or `container` context; the Feature sets `container`. It is a context
  marker, not an authorization boundary. Cross-environment entry/rebuild fails.
- `dev exec` replaces the process with argv, preserving project PATH, cwd,
  streams, terminal, signals, and status. It does not construct a shell command.
- [Activation](activation.md) preflights conflicts, preserves user content, rolls
  back failed writes, and keeps application-owned state outside packaged defaults.
  Repeating activation is offline. Existing processes are not reconfigured.
- `dev windows pop` validates selections before moving stable window IDs. Partial
  moves retain the original primary session; moving every window transfers its
  metadata. Running pane IDs/PIDs survive. **Ctrl-a g** uses the same command and
  passes the prompt response as literal data, including invalid shell-like input.

## Effective inspection

`dev languages FILE [--json]` opens the on-disk Python file using normal activated
Neovim startup, queries ALE and native client state, and retains native Ruff and
terminal Pyright reports. It reports the interpreter, selected executable paths,
versions, options, roots, directories, configuration evidence, and failures.
`:DevLanguages` queries the current editor buffer, including its unsaved state.

The inspection does not invent a shared settings resolver. Project checker policy
remains native Ruff/Pyright configuration. Configured OpenCode LSP choices are
reported separately from its **unresolved running selection**; agent/editor parity
is not established. The Pyright LSP's loaded configuration-file provenance is also
unresolved where the client does not expose it. Inspection starts editor/checker
processes and reads their evidence; it does not run the Python program or apply fixes.

## Verification

Initialize the recorded submodules, then use the [README setup](../README.md#set-up-the-baseline).
The project post-create hook activates defaults and provisions the separate locked
test environment. `dev test` uses the installed source snapshot and forwards pytest
arguments/status; missing or mismatched dependencies fail without installation.
Pytest caches live under `$XDG_CACHE_HOME/dotfiles/pytest`, outside the installed
source, and test imports do not write bytecode into that source.

```sh
devcontainer up --workspace-folder .
devcontainer exec --workspace-folder . dev test -q --opencode
devcontainer exec --workspace-folder . /opt/dotfiles-dev/venv/bin/python -I /opt/dotfiles-dev/source/tests/container_smoke.py
devcontainer exec --workspace-folder . make lint
```

The automated evidence covers:

- Repeated activation in isolated non-root homes, preservation/conflicts/rollback,
  runtime isolation, real OpenCode config and skill discovery without credentials.
- Both shell startup modes, real Tab completion, project PATH precedence, failed
  `cd`, spaces/symlinks, concurrent splits, prefix forwarding and tmux copy/paste.
- Real editor input/save/undo, native EditorConfig, definitions, hover, completion,
  diagnostic navigation, explicit formatting, and independently selected Python tools.
- An unconfigured workspace and projects with different interpreters and checker
  rules; missing, disabled, and failing selections without silent replacement.
- `tests/test_baseline.py`: normal activation/startup, locate a definition, observe
  a real diagnostic, explicitly change/format/save, and run the corresponding
  checker through `dev exec` in the inspected environment.
- `tests/test_windows.py`: attached prompt, original pane processes, primary
  identity transfer, detach, and fresh-launcher reconnection.
- `tests/container_smoke.py`: installed Feature as non-root, project venv isolation,
  argument/stream/status preservation, and metadata-based fresh-process discovery.

### Remaining acceptance boundaries

The automated Linux workflow is the baseline for subsequent comprehension work.
Manual delivery into the macOS host clipboard is still outstanding: tests assert
tmux buffers and emitted OSC52 bytes, not a desktop clipboard change. Follow
[the tmux manual check](tmux.md#headless-clipboard--ghostty) and the Neovim terminal
check, then record the result before treating that milestone criterion as complete.
Native macOS installation, desktop rendering, and x86_64 execution are unverified.

The base image digest, plugin revisions, personal archive checksums, npm lock,
and Python versions are recorded. Apt package selection and unhashed Python
artifacts remain reproducibility limits. Persistence across container recreation,
full install/upgrade/remove management, observed agent LSP parity, managed container
creation, and isolated agent execution remain roadmap work. None of these checks
establish hot reload, runtime migration, or a reader's independent comprehension.
