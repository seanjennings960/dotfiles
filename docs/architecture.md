# Dotfiles architecture

`dotfiles` provides a terminal-first workspace that keeps human understanding in
step with code changes. Developers can inspect meaning, predict behavior, run an
experiment, and review the evidence for a change. Useful feedback should remain
available while code is incomplete or erroneous, with gaps in knowledge explicit.

This document defines planned user-facing contracts; backend mechanisms belong
in Implementation. Delivery status and milestones are in the [roadmap](project.md).

## Concepts and ownership

The public model has three independent concepts:

| Concept | Responsibility |
| --- | --- |
| Workspace | A writable copy of project files and project-owned configuration. |
| Environment | Where commands run, which resources they can access, and how long processes and data live. Either host or container. |
| Personal toolset | The user's selected developer tools, versions, and default integrations, stored outside shared project configuration. |

`dev` owns the personal development experience; projects own dependencies,
lockfiles, build/test commands, and code policy. Applications resolve their own
settings and own their generated data. Personal operations preserve project and
existing user configuration, report conflicts, and are safe to repeat.

## Understanding code and changes

Selecting code, a diagnostic, or a command should lead to an explanation of its
meaning, relevant dependencies, and behavior in the selected environment. Users
can follow the explanation back to source, language documentation, analysis,
execution, tests, and recorded design decisions. A proposed edit includes what
behavior is intended to change or be preserved and how that claim can be checked.

Explanations distinguish static analysis, observations from a particular run,
documented intent, and agent hypotheses. Passing examples establish those cases;
claims about all executions need stronger evidence and explicit assumptions.
Unavailable information remains unresolved. An agent can retrieve evidence,
explain it, and propose an experiment; its prose does not establish the claim.

Start with the detail needed for the user's question, then offer definitions,
prerequisites, examples, or a deeper mechanism. Expertise varies by topic. Keep
the distinctions needed to reason correctly: two names having the same type
does not establish that they refer to the same object. Inspection is keyboard
accessible, with textual meaning available independently of color or diagrams.

## Live feedback and experiments

Live behavior has three separate contracts:

| Capability | Contract |
| --- | --- |
| Inspection during editing | Preserve available analysis through incomplete edits; identify unsupported or unresolved regions. |
| Re-evaluation after an edit | Run selected complete code with explicit inputs and setup; identify fresh versus accumulated runtime state. |
| Resuming existing execution | Reuse state only under a defined dependency, effect, and state-migration model. |

An answer identifies its relevant source or buffer version, tool and settings,
and environment. Execution results also identify inputs and runtime history.
Unsaved editor content and executed source must be distinguishable. Known changes
to dependencies invalidate affected results; previous observations remain
inspectable as stale evidence. Untracked external state is an explicit limit on
freshness and reproducibility.

Executable documentation connects editable examples, setup, expected behavior,
and observed results. Interactive use and automated checks consume the same
example source. Users can compare a prediction with stdout, stderr, exit status,
and relevant values, then rerun a variation. Shared sessions declare their state
and execution order; reset identifies which state is recreated.

Running examples, evaluating debugger expressions, and applying edits are
execution or mutation, even when initiated from an inspection view. They follow
the environment and agent-isolation contracts. Changes to code do not themselves
authorize repeating external effects. Recreating a process does not restore
files or services outside it. Conditional reuse must fall back to invalidation
or fresh execution when its assumptions cannot be established.

## Security and agent isolation

Treat agents and the code they execute as untrusted. Agents start in containers,
each with its own workspace copy, writable application state, and build/test
resources. Starting another agent must not reuse an existing agent's writable
environment. Human host entry does not authorize a host agent; managed host-agent
launches require separate, explicit user authorization.

An agent can access its workspace and explicitly granted resources. Access
outside that scope requires user permission. Grants identify the minimum data,
operations, and recipients needed; project configuration cannot grant host
access or elevate privileges. Host environments have the user's machine access
and do not provide agent isolation.

Mutable resource sharing is opt-in, with a named owner and a coordination rule
for writes. Communication grants expose bounded channels, not general host
command execution. Isolation applies to all code an agent runs, including
subprocesses, not only operations requested through its interface.

## Environment behavior

The workspace defaults to the enclosing project root, or the invocation
directory outside a project. An explicit path overrides discovery. New commands
start in the invocation directory when it lies inside the workspace, or at its
root otherwise; containers use the corresponding workspace path.

An unmanaged bare `dev` enters the host for human work. Inside a managed container,
it reconnects to human work in that container. Host-side container entry is explicit
and uses project environment configuration subject to the security contract. Missing
configuration or failed setup stops entry and execution without falling back to
the host. Host entry works without container configuration or running containers.

The active environment is local to the invoking terminal or command, never a
machine-wide switch. An unmanaged invocation defaults to the host. Host means
the machine running the launcher, not whichever machine runs a command.
Inspection names both the workspace and environment; unreachable-host operations
report that limitation.

Entry reconnects to existing work for the same workspace and environment when
available, preserving running processes and directories. Otherwise it starts
work after required setup. `dev exec` needs no interactive entry and preserves
arguments, working directory, streams, exit status, and terminal behavior.

Disconnecting leaves processes running while the environment remains alive.
Exiting a shell does not destroy its environment. Rebuild recreates a container
and ends its processes; it is unsupported on the host. Workspace files, saved
editor undo, and agent history survive recreation, but running processes do not.
A fresh launcher can reconnect without depending on a previous launcher process.

## Personal tools and project choices

Install applies the selected tools and exact versions. Upgrade selects newer
versions, records the selection, and reports individual failures. Remove affects
only personally managed installations and preserves dependencies still needed
by retained tools.
Unavailable versions and conflicts are reported, never silently substituted.

Container toolset changes normally take effect through rebuild. A temporary
install can try a prospective tool or package in the current container without
rebuilding or changing the saved selection. Inspection marks this runtime drift;
recreation discards it. Keeping the change requires explicitly recording the
package and version in the personal toolset or project dependency specification.
Temporary installation does not grant an agent privilege elevation.

Personal runtimes and checkers stay separate from project dependencies. Runtime
selection, checker selection, and code policy are independent and use the
applications' existing resolution rules. An unavailable project-selected tool
is not replaced with a personal default. Disabling an integration does not
uninstall shared tools or alter project configuration.

Read-only inspection distinguishes desired from installed tools and enabled
from effective integrations. It reports versions, executable paths, ownership,
environment, working directory, and settings sources. Disabled, unavailable, or
unresolved selections and differences between editor, agent, and terminal checks
are visible. A configuration file's presence is not proof of an active override.

## Reproducibility and efficiency

Reproducing code correctness requires more than tool versions. Record the code
revision, platform, base environment, direct and transitive dependencies,
configuration, setup/build/test commands, and required runtime inputs or services.
Projects supply their prerequisites; `dev` records the personal contribution.
Unpinned inputs, external state, and temporary changes are explicit limitations.

Environment creation reuses compatible prepared environments and cached inputs.
It works offline when prerequisites are cached and setup needs no network.
Report missing inputs; fetching them is explicit and preserves recorded versions.
Rebuild only when build inputs change or the user requests it. Share approved
immutable data read-only, but keep writable source, build output, test data, and
service state private unless sharing is explicitly coordinated. Apply
per-environment resource limits and measure startup and concurrent-agent costs.

Agent changes and execution history remain available for human review, correlated
with the workspace, starting code revision, and environment inputs. Projects own
their CI and integration policy.

## Command interface

The proposed interface expresses these contracts:

```text
dev                                    Enter or reconnect to human work in the current environment
dev env                                Show the environment and workspace
dev env enter host                     Enter or reconnect to host work
dev env enter container                Prepare and enter a project container
dev env rebuild                        Rebuild/recreate the container and enter it
dev agent start                        Copy the workspace and start an isolated agent
dev activate                           Apply personal configuration offline
dev tools                              Show desired and installed personal tools
dev tools install [<tool>]              Install defaults or a selected tool
dev tools install --temporary <tool>    Try a tool in the current container
dev tools upgrade                      Upgrade personal defaults
dev tools remove <tool>                Remove a personally managed tool
dev languages                          Show enabled and effective language support
dev exec <command>                     Run a command in the current environment
dev test [<test args>]                  Run this repository's automated checks
```

Agent selection and authorization options remain to be specified. Inspection and
experiment interactions should use existing editor and tool interfaces first;
add launcher commands only when a concrete workflow needs coordination.

# Implementation

## Components

| Component | Responsibility |
| --- | --- |
| Python and Click | Coordinate workspace entry, execution, and inspection using a runtime separate from project environments. Homebrew distribution is planned. |
| Ghostty or another terminal | Host terminal input and rendering. |
| tmux | Layout, keyboard navigation, running sessions, attachment and detachment. |
| Shell | Interactive execution and completion; evaluate Zsh after a Bash baseline. |
| Neovim | Editing, source selection, language-service results, navigation, and diff review. |
| OpenCode | Evidence retrieval, explanations, proposed changes and experiments, and conversation history. |
| Docker and Dev Container CLI | Container execution, image caching, volumes, limits, and project setup. |
| Personal Dev Container Feature | Versioned packaging of personal tools and defaults outside project configuration. |

Each project owns one definitive devcontainer image and its project toolchain.
The personal Feature adds the launcher and developer applications to that image,
with the launcher's runtime separate from project Python environments.

Start with Ubuntu 24.04 on `linux/arm64`, using `apt-get` and tool-specific
installers; host tools need macOS-compatible adapters. Python, Ruff, and Pyright
come first. Language profiles are internal bundles of independently enabled
runtime, formatter, diagnostics, and language-intelligence integrations. LSP is
one mechanism, not a requirement for every tool.

Use `.editorconfig`, project environments such as `.venv`, checker settings such
as `pyproject.toml`, and OpenCode's existing configuration resolution. Merge only
where supported and inspect application results rather than adding a second
resolver. A project can keep personal Ruff while choosing its own Python and
Ruff rules.

## Semantic services

An investigation relates source, environment, runtime observations, and history.
Choose a provider according to the question it can answer:

| Question | Semantic basis |
| --- | --- |
| What construct or declaration is this? | Syntax, binding, expansion, and source correspondence. |
| What types, values, or effects are possible? | Typing and static analysis, with the provider's approximation limits. |
| What happened, and what contributed to it? | Runtime states, execution traces, and data/control dependencies. |
| What should hold, and what was checked? | Specifications, tests, contracts, and proofs under stated assumptions. |
| What changes or remains equivalent? | Edit semantics, completion obligations, and observational equivalence. |

Use LSP or native language APIs for supported bindings, types, diagnostics, and
edits; DAP or runtime APIs for execution inspection; project test runners for
examples and expectations; and Git, documentation, and agent history for intent.
LSP transports selected results, not a complete semantic model or proof of their
correctness. Type derivations, slices, and ChatLSP-style relevant-context queries
may require language-specific extensions. Expose actual backend capabilities.

Connect authored language explanations and examples to source selections.
Agents should consume the same source-linked evidence available to humans.
Keep expected types, inferred types, and observed values distinguishable, and
preserve the limits of the evidence when summarizing it. Reuse native state and
configuration resolution; add records only for relationships those tools cannot
reconstruct, with an explicit owner and lifetime.

## Applying live-programming research to Python

Hazel's semantic foundations guide the design: incomplete programs and edits
deserve explicit meaning. Its hole semantics, type safety, and resumption
theorems are distinct results for specified calculi. Preserving meaningful edit
states does not imply preserving behavior or equivalence to a fresh execution.

For Python, begin with inspection through errors and reproducible execution of
complete examples. A recovery tree can represent missing syntax even when CPython
cannot execute the buffer. Annotations, `Any`, `None`, and `Ellipsis` do not supply
Hazel-style expression-hole semantics. Richer type explanations depend on the
analyzer; evaluating through missing expressions would require new runtime
semantics.

Incremental execution must account for mutable aliases, dynamic dispatch,
imports, native extensions, suspended computations, and external effects.
Capturing bindings does not snapshot the objects they reference. Define supported
operations, tracked dependencies, effect boundaries, and observations before
claiming reuse agrees with a fresh run. Treat hot reloading and state migration
as separate capabilities. Compare existing Python dataflow and notebook tools
before building a runtime; the roadmap scopes any hole-aware evaluator or
structural collaboration as research.

## Launch and persistence

1. Discover the enclosing Git worktree or use an explicit workspace path. Each
   worktree is a distinct workspace. Agent launches create separate clones or
   copies with independent writable Git metadata, not a shared working tree.
2. Validate project devcontainer settings against the granted access. Preserve
   permitted base image, user, hooks, and pins; reject conflicting privileges or
   mounts. Host-side lifecycle hooks require separate authorization.
3. Run `devcontainer up --additional-features` with the external personal Feature
   selection. Pin the Feature release/digest and tested CLI version. Cache builds
   by base image, Feature, configuration, and dependency inputs.
4. Activate defaults for the development user, wait for project setup, then use
   `devcontainer exec` to attach to tmux or execute a command. Resolve tools after
   setup. Host entry attaches locally without using the container backend.

Docker owns container/volume metadata; tmux owns session metadata. Discover both
rather than creating a second lifecycle registry. Persist Neovim undo and
OpenCode history outside packaged configuration, in storage scoped to the
workspace and user. Keep each agent's writable storage separate and reattach it
after recreation. Record branch, initial Git revision, and OpenCode conversation
ID for review through diffs and GitHub pull requests.

Tool or packaged configuration changes invalidate the affected image; unchanged
inputs reuse it. Mount changes recreate containers. Project settings reload the
affected application. Host updates affect future invocations; running tools may
need restarting. Temporary user-space installs use the container's writable
layer or disposable private volume, not persistent application-state storage.
System-package trials require a user-authorized, constrained installer, never
agent-accessible sudo.

## Enforcing the agent boundary

The host launcher and container runtime are trusted; agents and project launch
settings are not. Managed container agents run as non-root users without sudo,
privileged mode, host namespaces, excess capabilities, or Docker socket access.
Enable no-new-privileges and runtime syscall controls. Mount only the agent's
copy and approved state, not the host home, credentials, or unrelated workspaces.
Isolate service ports and networks; deny host-service and peer access by default
and grant required outbound access separately. Network names alone do not enforce
this policy. Setup code follows the same resource restrictions.

Root installation belongs to trusted build or constrained installer steps.
Project hooks cannot approve their own host execution or expanded access. A
host-side broker for sharing should expose named data/channel operations with
user-approved grants, not arbitrary commands. OpenCode workspace permission
prompts complement these runtime restrictions but do not constrain arbitrary
code launched by an agent.

Use Linux users, groups, and filesystem permissions for approved shared storage.
If swarm storage needs distinct identities, prototype host-managed UID/GID
provisioning; account creation is not an agent capability. Kernel/runtime
exploits remain outside the guarantee. Docker Desktop adds a Linux VM boundary on
macOS; this is not equivalent to a separate VM for every agent.

## Sharing and open questions

- Reuse read-only image layers, downloaded artifacts, and tool caches. A trusted
  cache writer publishes immutable entries; agents do not share writable caches.
- Prototype channel-based Unix domain sockets with private socket directories,
  peer authentication, and scoped operations. Sharing a channel must not expose
  the host runtime socket. Check transport across the macOS/Linux VM boundary
  before adopting it.
- Measure cached creation latency, offline setup, idle memory per agent, and
  concurrent build/test throughput. Docker overhead, especially its macOS VM,
  is an open risk. Compare alternatives if measurements miss the required budget;
  isolation remains mandatory. Numeric budgets need an initial baseline.

## Verification

Integration tests use isolated homes and workspaces and simulate terminal input.
Cover repeated activation, failed setup, reconnection, undo/history recovery,
project overrides, cached offline creation, temporary-install drift, and concurrent
agents unable to modify each other's source/state or reach ungranted host resources.
Run native macOS tests on a Mac and report emulation separately; manually verify
terminal rendering and system clipboard delivery.

For comprehension features, test the normal configured editor-to-execution path:
source navigation, partial-code failures, buffer/disk disagreement, changed
environments, stale results, reset/replay, and a documented example's expectation.
Runtime observations must refer to the source actually executed. Compare cached
and fresh execution only within the declared reuse model, including mutation and
effect cases that must invalidate it.

Evaluate human understanding separately through user-invoked prediction,
explanation, repair, and transfer tasks. Record task difficulty, assistance, and
confidence; use unfamiliar variations and delayed checks where useful. Report
task-specific results and distinguish aided completion from independent reasoning.
Automated correctness checks and fast task completion do not establish learning.

## References

- [Toward Semantic Foundations for Program Editors (SNAPL 2017)](https://arxiv.org/abs/1703.08694)
- [Live Functional Programming with Typed Holes (POPL 2019)](https://arxiv.org/abs/1805.00155)
- [Total Type Error Localization and Recovery with Holes (POPL 2024)](https://doi.org/10.1145/3632910)
- [Contextualized Programming Language Documentation (Onward! 2022)](https://doi.org/10.1145/3563835.3567654)
- [Statically Contextualizing Large Language Models with Typed Holes (OOPSLA 2024)](https://arxiv.org/abs/2409.00921)
- [Grove: A Bidirectionally Typed Collaborative Structure Editor Calculus (POPL 2025)](https://doi.org/10.1145/3704909)
- [Syntactic Completions with Material Obligations (OOPSLA 2025)](https://arxiv.org/abs/2508.16848)
- [Bidirectional Type Slicing (2026 preprint)](https://arxiv.org/abs/2607.12197)
- [Practical Algebraic Stepping with Scoped Filters (2026 preprint)](https://arxiv.org/abs/2605.31517)
- [Hazel Prover (2026 preprint)](https://arxiv.org/abs/2608.23309)
- [Hazel research and prototypes](https://hazel.org/)
- [Language Server Protocol](https://microsoft.github.io/language-server-protocol/overviews/lsp/overview/)
- [marimo execution model](https://docs.marimo.io/guides/reactivity/)
- [IPyflow dataflow and slicing](https://github.com/ipyflow/ipyflow)
- [IPython autoreload and its limits](https://ipython.readthedocs.io/en/stable/config/extensions/autoreload.html)
- [Dev Container Features](https://containers.dev/implementors/features/)
- [Dev Container CLI](https://github.com/devcontainers/cli)
- [EditorConfig](https://editorconfig.org/)
- [OpenCode configuration](https://opencode.ai/docs/config/)
