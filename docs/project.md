# Dotfiles Project Roadmap

## Vision

I want to recreate my terminal-first development workflow on a new machine,
compose it with project development environments, and eventually supervise
persistent coding sessions across local and remote computers.

**Dotfiles provides a working, versioned default environment. Projects can
override its tools and settings, and those overrides should be visible.**

The first deliverable is a host-side `dev` CLI and a Dev Container Feature that
bring my workflow and a complete Python language bundle into existing project
devcontainers. Rust and Julia support follow. The initial CLI implementation
will use Python for Docker-backed environments, migrating to Rust when adding
native environment support.

The design and ownership boundaries are described in
[Architecture](architecture.md). This document tracks delivery order,
investigations, and completion criteria.

## Starting Point

This repository began as versioned personal configuration with installation
scripts. Docker and devcontainers provide a more reproducible foundation. After
initially using Codex as an AI-first environment, I returned to a terminal-first
tmux and Vim-style workflow with OpenCode as the agent harness.

The next phase builds on:

- **tmux:** persistent terminal sessions, layouts, and personal keybindings.
- **Neovim:** the supported editor; the existing Vim and Neovim configurations
  need consolidation and a plugin inventory organized by capability.
- **Bash and Zsh:** existing shell configurations; Bash is the starting baseline,
  with Zsh evaluated during the first milestone.
- **OpenCode:** versioned personal configuration and reusable agent workflows.
- **`infectdots.sh`:** existing activation logic to evaluate for reuse.
- **Ghostty:** the host terminal and macOS integration.
- **The current Ubuntu 24.04 devcontainer:** an initial development and test
  environment for this repository.

Other configurations can be evaluated as the supported baseline becomes clearer.

## Developer Experience

On macOS, install the host-side `dev` command through Homebrew. From a project
directory, the proposed interface is:

```text
dev                  Launch or reuse the environment and attach to tmux
dev exec <command>   Run a command in the project environment
dev rebuild          Rebuild/recreate the environment and enter it
dev tooling          Inspect active runtimes, checkers, servers, and settings
```

Personal Feature selection should work without editing shared project
configuration. A project with no language-specific setup should get useful
defaults; a configured project should visibly identify the settings and
executables it overrides.

These commands describe the intended interface, not an existing implementation.

## Roadmap

### 1. Docker-backed Workflow and Python Baseline

**Deliverables:**

- Implement the host-side `dev` CLI in Python, targeting Docker-backed
  environments, and package it for Homebrew installation on macOS.
- Establish the Neovim baseline and inventory editor and OpenCode extensions
  by capability.
- Evaluate Bash and Zsh for completion, history behavior, keybindings, startup
  behavior, and compatibility with existing shell integration. Record the shell
  selected for the supported baseline.
- Provide reliable completion for paths, Git branches, and `dev` commands.
- Package personal defaults and executables as a versioned Dev Container
  Feature. Its final name and published package reference remain to be chosen.
- Provide a default Python runtime, linting, formatting, type checking, and
  language-server support. Ruff and Pyright are the proposed checker/server
  baseline; include their execution dependencies.
- Pin managed dependencies for each release and declare the tested Linux
  distribution and architecture matrix, starting with Ubuntu 24.04 and extending
  to a selected Debian baseline on `amd64` and `arm64`.
- Make activation repeatable for the configured development user and preserve
  existing shell and application configuration.
- Implement granular project overrides and visible configuration sources in
  Neovim, OpenCode, and `dev tooling`.
- Preserve component-owned editor state across rebuilds and discover existing
  environments and sessions without a duplicate `dev` registry.

**Completion criteria:**

1. Use the Feature in two existing Python devcontainers with different runtime
   environments and code policies; exercise both Dockerfile/image and Compose
   launch paths.
2. Verify that Python editing and checking work with the supplied defaults in a
   fixture with no project-specific language configuration.
3. Verify partial settings overrides, runtime and executable/version overrides,
   and explicit disablement. Display their sources accurately, including
   unavailable project-selected executables or environments.
4. Exercise completion, tmux keybindings, and editing through simulated input,
   including `git branch ma<Tab>` completing to `master` in a controlled fixture.
5. Repeat launch, activation, and rebuild operations; preserve Neovim undo
   history and introduce no shared configuration changes, including lockfiles.
6. Start a fresh `dev` process and rediscover the environment and sessions using
   configuration and component metadata; disposable caches are unnecessary for
   recovery.
7. Pass integration tests on the declared distribution/architecture matrix and
   exercise Homebrew installation and host-side launching on macOS.

### 2. Rust and Julia Language Bundles

Build on the Python selection, override-display, and testing conventions.

- **Rust:** provide a pinned runtime/toolchain, rust-analyzer, rustfmt, Clippy,
  and compiler checks through Cargo. Integrate project toolchain selection,
  Cargo configuration, and formatting settings.
- **Julia:** provide a pinned Julia runtime, LanguageServer.jl, and a formatter
  such as JuliaFormatter.jl. Integrate the active project environment and its
  `Project.toml`/`Manifest.toml`, plus formatter and server settings.
- Keep deeper Julia analysis, such as JET.jl, as a follow-up evaluation.

**Completion criterion:** exercise a default and a project-configured workspace
for each language. Verify runtime/toolchain selection, editing, checks,
formatting, displayed override sources, and repeat launches across the declared
support matrix.

### 3. Remote Continuity

Use named hosts, SSH, and tmux to access persistent work. Investigate OpenCode's
plugins, server API/SDK, and existing programs that can integrate session
discovery, notifications, and remote control. Produce a capability assessment
and one end-to-end prototype before designing additional coordination state.

**Completion criterion:** start work on a Linux host, disconnect, and reconnect
from my Mac to the same running session and workspace, with session discovery
and status reporting demonstrated by the integration prototype.

### 4. Rust CLI Migration and Native macOS Workflow

- Migrate `dev` from Python to Rust when adding native environment support.
  Preserve the established command, configuration, and component-state contracts
  through the same behavioral tests.
- Provide the repository's own build/test toolchain and any cross-compilation
  dependencies needed to build and package `dev`.
- Establish native macOS installation, editing, and checking with the language
  bundles and project-override behavior already exercised in containers.
- Build and test one real project through a consistent command on macOS,
  recording the source commit, toolchain versions, results, and artifacts.
- Use platform-appropriate hosts or runners for native execution, including
  macOS/Xcode builds.

**Completion criterion:** install the Rust implementation through Homebrew and
run the relevant CLI and native integration suite on the target Mac. Verify
compatibility with the Docker-backed workflow and complete the real project's
native build/test workflow. Cross-compilation alone does not establish native
runtime support.

### 5. Multi-agent Coordination

Build towards a swarm through independent tasks with clear ownership:

> One task -> one branch/worktree -> one agent session -> one result.

Use separate worktrees on a shared host and separate clones across machines.
Exchange results through commits and pull requests. Build task dispatch, status
reporting, and result collection on the remote-continuity findings, identifying
any durable integration records that existing component metadata cannot supply.

**Completion criterion:** run two independent tasks across two machines with
visible status and results returned as commits or pull requests.

Phones and voice interaction are longer-term clients for task input, session
summaries, and result inspection through the same coordination interface.

## Verification Strategy

Most of this project is integration work. Add tests with each milestone rather
than treating verification as a final packaging step.

| Test level | Method and observable outcomes |
| --- | --- |
| Feature installation | Use the Dev Container Feature test framework and scenarios to check pinned versions, user ownership, configuration composition, and repeatable activation. |
| Editor and shell integration | Drive Neovim through RPC/input APIs and shells through a pseudo-terminal. Assert saved file contents, indentation, checker findings, formatting, completion, and active configuration sources. |
| Full `dev` workflow | Launch real fixture environments through `dev`; exercise tmux bindings, reconnects, rebuilds, component-state persistence, discovery, and unchanged project configuration. |
| Native execution | Run the relevant suite on each declared native OS/architecture, including installation and runtime behavior; report emulated results separately. |

Use isolated homes and disposable workspaces for tests. Include a project whose
checker is installed during project setup, so tests exercise selection after
dependency installation. For persistence, save a known edit, recreate the
container, reopen the file, and assert that Neovim Undo restores its earlier
contents. Assert that displayed overrides match actual execution, rather than
merely checking for configuration-file existence.

## Separate Future Inquiries

- **Application-wide security audit:** cover the `dev` CLI, Feature installation,
  editor and OpenCode extensions, mounts and persistent state, credentials, and
  remote interfaces.
- **GitHub authentication:** investigate credential availability, persistence,
  and Git/API workflows separately, coordinated with the security audit. A
  reusable `github-pr` agent skill can build on those findings.

## Implementation Decisions to Record

- **Milestone 1:** shell evaluation result, plugin baseline, language dependency
  versions, default checker rules, Feature name, and exact support matrix.
- **Milestone 1:** personal launch-configuration format, project-specific command
  overrides, and UI support for persistent override indicators.
- **Milestone 2:** Rust/Julia provisioning and project-runtime selection details.
- **Milestone 3:** session-control interfaces and any necessary integration state.
- **Milestone 4:** first native project and build/cross-compilation strategy.

Technical references are collected in [Architecture](architecture.md#references).
