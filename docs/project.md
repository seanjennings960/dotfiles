# Dotfiles roadmap

## Goal

This project has two goals:
1. Develop a terminal-first IDE for understanding and changing programs through
   inspection, executable examples, and reproducible experiments.
2. Codify and improve my software development processes.

I want to explore, understand, and edit agent-generated code, rather than let
coding speed outstrip my understanding of it. The working loop is: read, predict,
experiment, inspect, change, verify, and review. Feedback should remain useful
while code is unfinished, with unresolved information and stale results visible.

The core is tmux, Neovim, a shell, and OpenCode, with Ghostty on my Mac. Personal
tools should follow me between projects and environments. Projects retain their
own dependencies, settings, and build/test policy. The [architecture](architecture.md)
defines those ownership boundaries and the contracts for explanations, execution,
and agent isolation. This document defines delivery order and completion checks.

## Delivery starting point

The starting `master` contained personal configuration, legacy installation
scripts, and an Ubuntu 24.04 devcontainer. This baseline reconciles the launcher,
activation, shell/tmux, Neovim/Python, and personal Feature implementations below.
The [integration evidence](milestone-1.md) records contracts and verification;
the table retains the source-PR history rather than implying those PRs were merged.

| Work | Existing PRs and integration notes |
| --- | --- |
| Launcher, activation, checks, and PR guidance | #14, #15, and #6; #25-38 split the alternative consolidation in closed #24. Reconcile overlapping implementations before merging. |
| Shell, editor, tmux, and Python | #16-19; preserve the findings and behavioral checks, including overlap with #3, #8, and #9. |
| Learning material | #22 supplies the Zsh tutorial and fixed demonstrations; #23 evaluates simplification and prerequisite ordering. |
| Agent history | #39 proposes searchable OpenCode transcripts. |
| Container context and Feature packaging | #40 builds on #25; #41 builds on #40 and supplies the initial reusable personal devtools Feature. |

`dev languages` now reports native terminal/editor evidence and explicit unresolved
agent selections. Homebrew distribution, full tool lifecycle management, managed
container creation, and isolated agent launch remain planned. The comprehension
features below build on the integrated Linux workflow.

## Approach

Deliver one usable investigation workflow at a time, with its behavioral checks
in the same reviewable change. Begin in the Ubuntu 24.04 ARM64 project environment;
add native macOS installation and checks as that path becomes available. The
launcher keeps its runtime separate from project Python environments.

Use existing editor, language-server, runtime, and test interfaces first. Add
coordination only where a concrete user task needs it. Keep architecture focused
on user contracts and this roadmap focused on delivery. The research behind the
design is linked in the [architecture references](architecture.md#references).

`dev test` is the common entry point for this repository's checks. Keep
it a thin wrapper over the chosen test runner, forwarding arguments and exit
status. Projects own their test commands, which can run through `dev exec`.
Installation and dependency resolution are explicit setup steps.

Start each comprehension slice once its prerequisites work: the tutorial needs
the selected shell and example checks; Python inspection needs the editor and
analyzer. Broader packaging and tool management can progress alongside them.
Update the README as commands and workflows become available.

## 1. Integrate a reliable inspection and execution baseline

**Status:** implemented with integrated automated Linux ARM64 checks. The manual
host-clipboard delivery criterion below remains outstanding; native macOS is not
yet a verified installation target. See [baseline evidence](milestone-1.md) for
the installed workflow and remaining acceptance boundaries.

Integrate the existing work before relying on it in a comprehension feature:

- Launcher and activation: worktree-aware discovery, explicit workspace selection,
  invocation directories, faithful command execution, and fresh-process tmux
  reconnection. Activate twice in a non-root home, preserve existing configuration,
  report conflicts, and roll back failed writes. Keep writable application state
  outside packaged defaults and use backend metadata for discovery.
- Shell and tmux: preserve project executable precedence, failed `cd` status, and
  per-pane logical paths, including spaces and symlinks. Test repeated login,
  non-login, interactive, and noninteractive startup. Exercise completion, prefix
  forwarding, concurrent splits, window moves, and copy/paste through real terminal
  input. Verify delivery to the host clipboard manually.
- Neovim and Python: use one production startup, pinned plugins, native EditorConfig,
  and independently selected Python, Ruff, and Pyright. Verify editing, saving,
  navigation, hover, completion, diagnostics, and explicit formatting. Keep
  application-owned state recoverable and startup free of installation or updates.
- Effective-tool inspection: report actual executable paths, versions, interpreter,
  directory, settings sources, and differences between editor, terminal, and agent.
  Exercise project overrides, unavailable selections, disabled integrations, and
  the ALE/Pyright settings bridge from #19. Report unresolved choices explicitly.
- Local container execution: integrate #40-41 so each project owns its definitive
  image/toolchain and the personal Feature supplies the launcher and personal
  tools. Distinguish local container use from host-managed creation or rebuild.

Use fixtures with an unconfigured Python workspace and two projects selecting
different interpreters and checker rules. Test through normal activation and
startup, including missing prerequisites and failed setup without host fallback.

Done when the installed workflow can locate a definition, show a real diagnostic,
run the corresponding project check in the inspected environment, and reconnect
to the same work. Include the relevant tests with each feature; existing reports
from separate branches do not replace verification of the integrated setup.

## 2. Make the Zsh tutorial executable

Build on #22's context, arguments, execution, and interaction model. Deliver the
notebook-like interaction requested in its review:

- Read an explanation, select and edit its example, run it, and inspect exact
  source, stdout, stderr, and exit status. Link unfamiliar constructs to their
  prerequisites and language documentation.
- Use the same example source for interactive execution and automated expected
  results. Replace the disconnect between chapter snippets and fixed demonstrations.
- Declare setup, inputs, working directory, and interpreter. Identify fresh versus
  shared sessions, execution order, and reset behavior. Editing an example makes
  its previous output visibly stale; retain that output for comparison.
- Use disposable practice state and bounded execution with timeout cleanup.
  Integrate example checks with the repository test entry point. Keep the tutorial's
  directory-selection helper distinct from the architecture's workspace concept.

Done when I can predict the arguments or pipeline status of a chapter example,
run a variation, explain the difference, and reproduce its expected result through
the automated checks. Verify keyboard use, reset/replay, failures, and missing
prerequisites. Try an unfamiliar variation with a reader to evaluate understanding
separately from the example's technical correctness.

## 3. Connect Python explanations to controlled experiments

Once editor and analyzer integration works, this can proceed alongside the
tutorial. Bring the same investigation loop to ordinary project code:

- Select an expression, binding, or diagnostic in Neovim. Show available type and
  definition information, related source, and the actual analyzer/configuration.
  Offer concise explanations with deeper mechanisms and examples on request.
- Preserve useful inspection through incomplete edits where the backend supports
  it. Identify blocked regions and missing capabilities. Execute only a selected
  complete unit with its declared inputs and setup; an analyzer's recovery tree
  does not make an incomplete buffer executable by CPython.
- Record the exact source snapshot used for execution, including the distinction
  between an unsaved buffer and disk. Attach interpreter, dependencies, directory,
  inputs, and relevant runtime history to results. Mark known input changes stale
  and expose untracked external state as a reproducibility limit.
- Show relevant values or traces and compare a counterfactual edit. Begin with
  fresh, controlled execution. Specify reset behavior before offering shared
  sessions; defer cached reuse until its dependency/effect contract is tested.

Use list aliasing/mutation and interpreter-dependent imports as initial cases.
Done when I can follow an explanation to its source evidence, reproduce the
behavior, inspect a proposed change, and check its intended effect. Cover unsaved
edits, changed environments, incomplete code, stale results, and reset. Evaluation
through a debugger or probe follows the same execution contract as a command.

## 4. Connect agent explanations and continuous review

- Give humans and agents access to the same versioned, source-linked evidence.
  Start with supported language queries; investigate ChatLSP-style expected types
  and relevant definitions where the backend exposes them. Keep inferred types,
  expected types, runtime observations, and generated hypotheses distinguishable.
- Connect a proposed change to its intent, affected code, experiments, test results,
  and review decisions. Build on #39 for history access while letting OpenCode own
  its transcripts. Record the starting revision, environment, and conversation ID.
- Let the user choose whether to propose a result and have it checked or request
  a suggestion. An explanation request does not itself apply the suggested edit
  or execute the selected program. Agent-run experiments require the isolated
  execution support described below.

Done when a reviewer can trace a claim from a diff to its supporting source and
execution, reproduce a check, and identify unsupported assumptions. Verify that
history for an older revision is not presented as current evidence. Keep project
CI and merge policy project-owned.

## 5. Prototype stronger semantics where the workflow needs them

Evaluate these research directions against concrete failures in the earlier
milestones. Each prototype needs a supported language/operation scope, a stated
guarantee, counterexamples outside that scope, and an end-to-end demonstration.

| Direction | Question to resolve before adoption |
| --- | --- |
| Contextual documentation and type slicing | Can the backend explain why a type is inferred or expected and expose the supporting source, including errors? |
| Syntax recovery with explicit obligations | Can unfinished syntax remain inspectable without silently guessing the intended repair? Compare Tylr-style obligations with existing recovery. |
| Filtered stepping and rich probes | Can users choose useful trace detail or inspect a value while preserving source correspondence? Any view-driven edit must produce reviewable source. |
| Incremental Python execution | Under which aliasing, mutation, import, native-code, and external-effect assumptions does reuse agree with a fresh run? Compare marimo and IPyflow; test invalidation boundaries. |
| Hole-aware execution | What runtime extension and supported Python subset would give missing expressions meaning? Study Hazel's effect and resumption limits. |
| Structural collaboration | Can stable identities and edit histories preserve inspectable conflicts? Evaluate Grove against the current Git-based review workflow. |

Semantic inspection, re-evaluation, and migration of a running process remain
separate capabilities. Report formal guarantees, runtime benchmarks, and reader
outcomes with their respective scope and assumptions.

## Supporting environment work

Continue the infrastructure contracts alongside the comprehension milestones:

- **Personal tools:** implement exact selections, install/upgrade/remove, ownership,
  and desired-versus-installed inspection. Preserve shared dependencies and project
  lockfiles; test conflicts, disabled integrations, and partial upgrade failures.
  Keep offline configuration activation separate from installation.
- **Distribution:** package versioned tools/defaults through the personal Feature
  and add Homebrew launcher distribution with macOS installer adapters. Test the
  declared platforms natively and report emulation separately.
- **Managed containers:** implement host-side entry and rebuild, preserving project
  pins and permitted hooks. Cover image/Dockerfile and Compose projects, present
  and absent lockfiles, failed setup, and tools installed during setup. Discover
  through Docker metadata and keep personal selections outside shared configuration.
- **Persistence and efficiency:** verify application-history recovery after
  recreation while distinguishing process lifetime. Record reproducible inputs,
  test cached offline setup, report missing inputs, and make temporary-install
  drift explicit. Measure startup, memory, and concurrent-test throughput before
  choosing budgets or scaling agent counts.
- **Isolated agents:** enforce the architecture's workspace, state, privilege,
  filesystem, and network boundaries before implementing `dev agent start`.
  Concurrent agents must not modify each other's state or access ungranted host
  resources. Coordinate any shared mutable resources explicitly; cache immutable
  inputs read-only. Prototype scoped channels only for demonstrated sharing needs.

Done when either configured Python project can enter, reconnect, and rebuild
without changing shared configuration or lockfiles, with saved history recovered
and failures accurately reported. Host entry must work independently of Docker.
Native macOS checks must exercise the installed runtime and real terminal path.

Remote SSH reconnection, Rust/Julia language support, and phone or voice interfaces
follow demonstrated local workflows. Extend existing authentication and PR tooling
as remote integration needs it. A Rust launcher rewrite requires a concrete need.

## Evaluation

Automated checks verify accurate evidence, reproducible examples, and the declared
execution contracts. Human evaluation asks whether I can predict, explain,
diagnose, and modify an unfamiliar variation after using the tools. Record
prediction/transfer accuracy, successful repairs, assistance, and confidence on
comparable tasks. Distinguish aided completion from independent reasoning and
revisit concepts later when retention matters. Neither a passing test suite nor
shorter completion time establishes understanding.
