# Dotfiles Project Roadmap

## Vision

I want to recreate my terminal-first development workflow on a new machine,
compose it with project-owned development environments, and eventually supervise
persistent coding sessions across local and remote computers.

The central boundary is: **this repository owns how I work; each project owns
how its code is built, checked, and run.**

The first concrete deliverable is a versioned Dev Container Feature that adds
my developer tools and personal defaults to an existing project devcontainer.
I should be able to inject it through my own launcher without changing the
project's shared configuration. The initial focus is my daily workflow, with
broader portability growing from that foundation.

## Project History

The name `dotfiles` comes from the hidden configuration files traditionally
used to customize developer tools. This repository started as a way to version
and install those personal configurations.

Docker added a level of environmental reproducibility that previously relied
on sporadic setup scripts. Devcontainers build on containers with a description
of the workspace, toolchain, and setup lifecycle that development tools can use.

With agentic coding, I initially used Codex as an AI-first development
environment. I have since returned to my terminal-first `tmux` and Vim-style
workflow, with OpenCode as the agent harness. Neovim will be the supported editor
for the new developer-tools layer.

## Core Components

There is quite a bit of this repository that I do not actively use. The core
components for the next phase are:

1. **tmux:** persistent terminal sessions, layouts, and my personal keybindings.
2. **Neovim:** my Vim-style editing workflow. The existing Vim and Neovim
   configurations need to be consolidated into a clear baseline, with plugins
   inventoried by the capabilities they provide.
3. **Bash:** the initial supported shell, including my aliases and shell
   integration. Personal settings should compose with the environment's shell
   startup configuration.
4. **OpenCode:** the agent harness, with versioned personal configuration and
   reusable workflows such as the proposed `github-pr` skill.
5. **`infectdots.sh`:** the current configuration activation script. Its reusable
   activation logic can support both native-host and container installation.
6. **Ghostty:** the host-side terminal and macOS integration.
7. **Dev Container Feature and launcher:** the planned packaging and personal
   injection mechanisms for the container-side tools.

The remaining configurations can be evaluated as the supported baseline becomes
clearer.

## Architecture and Ownership

| Layer | Responsibility |
| --- | --- |
| Host setup | Install the terminal, Docker runtime, Dev Container CLI, and host-specific integration. |
| Developer-tools Feature | Install tmux, Neovim, Bash, OpenCode, personal defaults, editor integrations, and reusable agent workflows. |
| Project devcontainer | Supply project dependencies, compilers, language servers, linters, formatters, and their versions. |
| Project configuration | Define code policy, build/check commands, and project-specific editor and agent settings. |
| Personal launcher | Select my Feature version and options, launch the project environment, and enter its workspace. |
| Session and coordination | Keep work accessible, discover remote sessions, dispatch tasks, and collect results. |

The Feature owns the interface to language tooling; the project owns the
executables and rules. The personal tool layer should be reusable across
repositories with different toolchains.

### Initial Support

The first Feature will support Debian/Ubuntu containers on `amd64` and `arm64`.
This covers the current Ubuntu devcontainer and Linux containers on x86 machines
and Apple Silicon Macs. The longer-term goal is portability across machines
with a compatible Docker runtime, extending the supported container base images
as needed.

Start with declared dependencies, pinned plugin commits, versioned defaults,
and repeatable setup. Record installed tool versions and tighten version
pinning where drift matters.

## Personal Devcontainer Injection

The Dev Container CLI supports adding Features through `--additional-features`.
A small host-side launcher will use this mechanism to compose my developer tools
with the project's existing image, Dockerfile, or Docker Compose configuration.
With Compose, the Feature applies to the designated development service.

The launcher will read personal Feature selection and options from outside the
project, for example `~/.config/devtools/features.json`. This would be the
launcher's configuration format, not a standard devcontainer override file.

Once the Feature is published, the underlying CLI workflow would look like:

```bash
devcontainer up \
  --workspace-folder . \
  --additional-features \
    '{"ghcr.io/seanjennings960/dotfiles/developer-tools:1": {}}' \
  --no-lockfile

devcontainer exec --workspace-folder . tmux new-session -A -s dev
```

The package reference above is proposed, not an already-published Feature.
The launcher should pin my chosen Feature release in personal configuration.
For projects with a checked-in devcontainer lockfile, use `--frozen-lockfile`
to honor the project's pins without rewriting it. For projects without one,
use `--no-lockfile` to avoid generating repository configuration as part of
personal setup.

Feature injection happens during image build and container creation. Adding
or updating the Feature requires rebuilding/recreating an existing container;
subsequent launches can reuse it. The launcher should expose convenient launch,
entry, and rebuild operations.

VS Code also supports personal Feature selection through the User Setting
`dev.containers.defaultFeatures`. The standalone CLI does not read that setting;
the terminal-first launcher will supply its own additional Features.

### Installation and Activation

Separate three stages:

1. **Image build:** install tool binaries and package personal defaults.
2. **Container creation:** initialize writable configuration for the configured
   development user, with repeatable activation that composes with existing
   configuration.
3. **Tool startup:** discover the current project settings and executable paths.

Feature installation runs as root. User configuration should target the
configured development user rather than assume that root's home is the user's
home. Runtime state such as credentials, caches, and agent history needs its own
persistence arrangement.

Feature lifecycle hooks run before project hooks in the same phase. Discovery
of project-installed tools should therefore happen when those tools are used,
after project dependency setup has completed.

## Project Integration

The first integration contract should use conventions projects already have:

- **`.editorconfig`:** basic whitespace and indentation policy, with support in
  the editor baseline.
- **Native linter and formatter configuration:** rules in files such as
  `pyproject.toml` or `eslint.config.js`.
- **Project task commands:** canonical build, test, lint, and format commands in
  the project's existing Makefile, package scripts, or scripts directory.
- **Editor adapters:** invoke project-installed diagnostics tools with the
  correct working directory and environment.
- **OpenCode configuration:** personal defaults in the user-global configuration;
  project settings in `opencode.json` or `opencode.jsonc`, extensions in
  `.opencode/`, and guidance and check commands in `AGENTS.md`.

For example, a Python project can install its chosen Ruff version and define
rules in `pyproject.toml`. Neovim diagnostics, OpenCode, terminal checks, and CI
should then use the same project-owned tooling and policy.

A documented, opt-in editor-specific override mechanism may be needed for
projects that require additional adapter or command selection. Its format is
still an open decision. Basic adoption should work with the project's existing
configuration.

## Roadmap

### 1. Developer-tools Feature and Personal Launcher

- Establish a supported Neovim baseline and inventory plugins by purpose.
- Package the container-side tools and personal defaults as a versioned Feature.
- Make activation repeatable and appropriate for the configured development user.
- Add a host-side launcher for personal injection and workspace entry.

**Completion criterion:** inject the Feature into two existing devcontainers
with different project toolchains. Verify the same personal workflow, correct
project-specific indentation and diagnostics, and successful repeat launches
and rebuilds. The launcher should introduce no shared configuration changes.
Exercise the declared distribution and architecture support matrix.

### 2. Remote Continuity

Start with named hosts and sessions, using SSH to connect and tmux to maintain
sessions on each machine. Processes remain on their execution host; reconnecting
from another device resumes access to that work. Container sessions persist
while their container continues running; rebuilding replaces the container and
ends those sessions.

**Completion criterion:** start work on a Linux host, disconnect, and reconnect
from my Mac to the same running session and workspace.

### 3. Native macOS Build Workflow

Use a uniform workflow to build and test on platform-appropriate machines,
starting with macOS. A Linux devcontainer can orchestrate native macOS builds;
macOS/Xcode execution requires a macOS host or runner. Cross-compilation remains
a project-specific toolchain capability.

**Completion criterion:** build and test one real project on macOS through a
consistent command, recording the source commit, toolchain versions, results,
and artifacts.

### 4. Multi-agent Coordination

Build towards a swarm through independent tasks with clear ownership:

> One task -> one branch/worktree -> one agent session -> one result.

Use separate worktrees on a shared host and separate clones across machines.
Exchange results through commits and pull requests. Add session discovery,
task dispatch, status reporting, and result collection as concrete needs emerge.
OpenCode's server API is a starting point to evaluate for cross-machine control;
skills and plugins can supply reusable workflows and local lifecycle behavior.

**Completion criterion:** run two independent tasks across two machines with
visible status and results returned as commits or pull requests.

Phones are a longer-term client for task input, session summaries, and result
inspection. Voice interaction can build on the same coordination interface.

## Open Questions

- Which Neovim plugins and configuration form the smallest useful daily baseline?
- What editor-specific project override mechanism is needed beyond standard
  configuration discovery?
- How should personal credentials and session state persist across rebuilds and
  be made available on each execution host?
- Which real project and toolchain should establish the native macOS workflow?
- What session registry and task-control interface are needed, and which parts
  can use OpenCode's existing API, skills, or plugins?
- What interaction model makes remote supervision useful from a phone?

## References

- [Dev Container Feature specification](https://containers.dev/implementors/features/)
- [Dev Container CLI](https://github.com/devcontainers/cli)
- [VS Code personal Feature settings](https://code.visualstudio.com/docs/devcontainers/containers#_always-installed-features)
- [OpenCode configuration layering](https://opencode.ai/docs/config/#locations)
- [OpenCode server API](https://opencode.ai/docs/server/)
