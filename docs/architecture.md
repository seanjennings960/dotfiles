# Dotfiles Architecture

This is the planned design. Architectural contracts describe what users and
projects can rely on; the implementation section identifies the technologies
used to satisfy them. Delivery milestones belong in the [roadmap](project.md).
The roadmap's current container-first sequence and CLI examples predate the
host-first contracts below and need alignment in a subsequent revision.

## High-level Design

`dotfiles` provides a terminal-first development workspace for human-agent
collaboration. Its `dev` CLI manages personal developer tools and connects users
to host or container environments. The interactive experience is composed from
the terminal multiplexer, shell, editor, and coding agent.

The first target host is macOS, with the launcher installed through Homebrew:

```sh
brew install dotfiles
```

Installing the launcher supplies its execution dependencies. Personal toolset
installation is a separate operation through `dev tools install`. The launcher
must run independently of a project's Python environment.

Bare `dev` is equivalent to `dev env enter host`. Container entry is explicit,
including in projects that contain devcontainer configuration.

The central ownership rule is:

> `dev` owns the personal development experience; the project owns the software
> being developed.

## Goals

- Keyboard-based code editing and navigation.
- Integrated formatting, diagnostics, and language intelligence.
- Versioned personal defaults that work on the host and in project containers.
- Reusable environments with explicit persistence and isolation guarantees.
- Observable agent execution and continuous human review.

## Concepts and Ownership

| Concept | Responsibility |
| --- | --- |
| Workspace | Project files and project-owned configuration. Each Git worktree is a distinct workspace. |
| Environment | The execution context for a workspace: host or container, filesystem access, development user, and lifecycle. |
| Personal toolset | The user's selected defaults and requested versions, stored outside shared project configuration. |
| Tool | A versioned, installable component providing executables or integration capabilities. One tool can provide multiple commands; editor plugins are tools too. |
| Language profile | A named grouping of tools and integrations for a language's runtime, formatting, diagnostics, and language intelligence. |

`dev` manages the personal toolset and its realization in each environment.
Projects own application dependencies, dependency lockfiles, build/test commands,
code policy, and project-specific tool selections. Applications resolve their
own settings and own their generated state. Environment and terminal backends
own container and session lifecycle metadata.

Personal operations must preserve shared project configuration and lockfiles.
Existing user configuration is preserved during activation; a conflict is
reported rather than silently overwritten. Repeated activation is safe and
reports failures accurately.

## Architectural Contracts

### Workspace and Environment Selection

The workspace defaults to the enclosing Git worktree root, or the invocation
directory outside Git. An explicit workspace path overrides discovery. New
terminal sessions and `dev exec` start in the invocation directory when it is
inside the selected workspace, or at the workspace root otherwise. Container
execution uses the corresponding directory in the mounted workspace.

Host means the machine running the host launcher. A container is a separate
execution environment and must not be reported as the host simply because a
command runs inside it. Operations requiring an unreachable host report that
limitation.

The active environment is scoped to the invoking session. Entering an
environment opens or attaches to its terminal workspace; it does not change
unrelated sessions or mutate the caller's shell environment. Outside a managed
session, the active context is the host. Inspection reports both the environment
and workspace it is describing.

Host entry works without devcontainer configuration or a running container
backend. Container entry uses the project's devcontainer configuration and
preserves its base image, development user, setup hooks, and project pins.
Missing configuration or failed setup is reported; container entry does not
silently fall back to host execution.

### Entry, Execution, and Lifecycle

Entry reuses a running terminal session for the same workspace and environment
when available, preserving that session's working directories and processes.
Otherwise it creates one after the environment is ready. Missing prerequisites
are reported with the appropriate setup action. Project setup required for
container use completes before attachment or command execution. Tools are
resolved when used so that setup-installed dependencies are available.

`dev exec` runs in the invoking context's environment without requiring an
interactive terminal session. It preserves command arguments, working
directory, standard streams, exit status, and interactive terminal behavior
when a terminal is present. A failed environment setup prevents execution.

Detaching a terminal client leaves its session running while the execution
environment remains alive. Exiting a shell ends that shell; it does not request
container destruction. Rebuilding recreates the container and ends its running
processes. Rebuild is a container operation; invoking it for the host reports an
unsupported operation.

There is no machine-wide active-environment switch. A fresh launcher process
can discover and reconnect to existing environments and sessions using backend
metadata. Any discovery cache is disposable.

### Personal Tool Management

`dev tools` manages personal defaults in the invoking context's environment.
The personal toolset specification expresses desired tools and versions;
inspection separately reports what is installed. A failed or incomplete install
must remain visible as a difference between those states.

- **Install** realizes the selected defaults, including requested versions. It
  reports conflicts with installations it does not own instead of taking them
  over implicitly.
- **Upgrade** selects newer versions of personal defaults and realizes that
  selection. It records the requested versions and reports individual failures.
- **Remove** removes a tool from the personal selection and removes its managed
  installation where supported. Project-owned or independently installed tools
  remain outside its ownership. Shared dependencies still required by retained
  tools are preserved.

On the host, changes use installers appropriate to that platform. In containers,
changes update the personal toolset used for image construction and take effect
through rebuild/recreation. An operation reports whether the current environment
already reflects the selection or still needs recreation. Packages installed
manually in a running container are not part of the reproducible specification.

The selected installation mechanism must support the requested version or
report it as unavailable. Substituting a different version silently is not
allowed. Personal tool versions can differ from project-selected versions.

### Defaults and Project Overrides

Keep personal runtimes and checkers separate from project dependency
environments. Use each component's existing resolution rules: `.editorconfig`
for editor policy, checker configuration such as `pyproject.toml`, project
language environments, and the coding agent's personal/project configuration.
Merge settings only where that component supports merging.

Runtime selection, checker selection, and code policy are independent choices.
For example, a project can use its `.venv` and Ruff rules from `pyproject.toml`
while retaining the personal Ruff executable. An explicitly selected but
unavailable project tool is reported as unavailable; it is not silently replaced
by a personal default.

`dev` supplies integrations and observes application resolution. It delegates
project dependency installation and selection to the project's existing tools
and conventions. A custom project override format requires a concrete need
that those conventions cannot satisfy.

### Language Profiles and Inspection

A language profile can provide independently enabled capabilities:

- Runtime or interpreter defaults.
- Formatting.
- Linting and type-checking diagnostics.
- Completion, navigation, and hover.

An LSP server is one integration mechanism; formatters and other tools can use
different interfaces. Project dependency management remains project-owned even
when a personal default supplies the manager's executable. Python is the first
profile.

Disabling a profile stops its default integrations without removing shared
tools or changing project configuration. Installed tools and enabled
capabilities are separate states.

`dev tools` reports desired and installed personal tools, their versions, paths,
and ownership. `dev languages` reports enabled capabilities and effective
runtime/checker selections for the workspace, including executable paths,
versions, environment, working directory, and relevant settings sources.
Disabled, unavailable, and not-yet-resolved selections are explicit.

Effective inspection uses the applications' resolution results. A configuration
file's presence alone is not evidence of an override. If an application has not
resolved a selection, inspection reports that limitation rather than presenting
an inferred default as observed behavior. Editor, agent, and terminal checks
should use matching selections when configured for the same capability; any
differences must be visible.

### State and Reconnection

Workspace files, persistent application data, and running processes have distinct
lifetimes. Workspace files and designated application state survive container
recreation. A terminal session survives client disconnection only while its
execution environment stays running.

The editor owns undo history; the coding agent owns conversations and generated
data. Writable state is separate from packaged configuration. On the host it
uses the user's application state locations. In containers, designated state
uses persistent storage associated with the development user and workspace
where applicable, and is reattached after recreation.

A new editor process must be able to recover saved undo history after container
recreation. Agent session history must likewise remain discoverable. Persisting
files does not promise recovery of running processes after restart or rebuild.

### Versions, Reproducibility, and Isolation

Personal defaults are versioned. Record requested and installed versions of
managed runtimes, executables, plugins, and their dependencies. Versioned
container toolsets reference exact releases or digests; reproducibility also
depends on the project base image, package sources, and dependency locks.
Unpinned or unavailable inputs are reported as limitations.

Host environments operate within the user's existing machine and share its
filesystem and system state. They do not provide container-style isolation.
Container environments provide a separate execution filesystem with explicitly
shared workspace and state storage. Project dependency reproducibility remains
the project's responsibility. Cost efficiency comes from reusing environments
and sessions; resource limits remain the environment backend's responsibility.

Host tool updates affect future tool invocations; running applications may need
restarting. Updated container tools or packaged configuration require rebuilding
and recreating the container. Project settings and supported external personal
overrides require the affected application to reload. Mount changes require
container recreation.

### Continuous Integration, Review, and Observability

Projects own their CI commands and integration policy. The development workspace
makes those commands available in the intended environment and supports human
review of agent-produced changes through GitHub pull requests and application
diff views.

Git history and pull requests record code changes and design decisions. Retained
agent sessions provide execution context. Sessions must remain identifiable by
workspace and session ID. For Git workspaces, record the branch and Git revision
at the start of work for correlation. The agent remains the source of its
conversation history; `dev` preserves access to that history through the state
contract above.

Integration tests verify interactions between real components using isolated
homes and workspaces, including simulated terminal input. They cover repeated
activation, failed setup, reconnection, persistence, and project overrides.
Native macOS behavior is verified on a Mac; Linux container coverage does not
establish host behavior. Emulated tests are reported separately. Terminal
rendering and actual system clipboard delivery also need manual verification.

### Command Interface

The planned public interface follows the ownership boundaries above:

```text
dev                         Enter or attach to the host workspace
dev env                     Show the current environment and workspace
dev env enter host          Enter or attach to the host workspace
dev env enter container     Prepare and enter the project's devcontainer
dev env rebuild             Rebuild/recreate the current container and enter it
dev tools                   Show desired and installed personal tools
dev tools install           Install the selected personal defaults
dev tools upgrade           Upgrade personal defaults
dev tools remove <tool>     Remove a personally managed tool
dev languages               Show enabled profiles and effective selections
dev exec <command>          Run a command in the current environment
```

`env`, `tools`, and `languages` inspection is read-only. Command options for
workspace selection and targeted tool/profile operations will be specified in
the implementation section.

# Implementation

The implementation builds on existing technologies:

| Component | Responsibility |
| --- | --- |
| Python and Click | The host-side `dev` CLI, packaged through Homebrew with its own Python runtime. |
| Ghostty or another terminal | Host terminal input and rendering. |
| tmux | Terminal layout, keyboard navigation, running sessions, and attachment. |
| Shell | Interactive command execution and completion; Zsh is the proposed default. |
| Neovim | Keyboard-focused editing, undo history, and language integrations. |
| OpenCode | Agent-assisted development, conversation state, and code inspection. |
| Docker and Dev Container CLI | Container execution and project devcontainer lifecycle. |
| Personal Dev Container Feature | Container packaging of the selected personal tools and defaults. |

The host toolset requires macOS-compatible installers. The container toolset
starts with Ubuntu 24.04 on `linux/arm64`; its package installation can use
`apt-get` alongside tool-specific installers. Python, Ruff, and Pyright are the
initial language tools.

For container entry, the existing implementation direction is:

1. Read the project's devcontainer configuration and the personal Feature
   selection, which lives outside the project.
2. Call `devcontainer up` with `--additional-features` to add the selected Feature
   to the image/Dockerfile or Compose development service. Preserve project pins
   and leave shared configuration and lockfiles unchanged.
3. Activate defaults for the configured development user, with writable
   configuration and persistent state directories. System dependency installation
   runs as root; usable configuration and application data belong to that user.
4. Wait for required project setup, then use `devcontainer exec` to attach to
   tmux or run the requested command.

Docker owns containers and persistent volumes; tmux owns sessions. Neovim and
OpenCode retain ownership of their configuration resolution and generated data.
Use an exact Feature release or digest and a tested Dev Container CLI version.
Docker Desktop runs Linux in a VM on macOS; `amd64` containers on Apple Silicon
use emulation.

Host launch mechanics, installer adapters, configuration locations, and the
remaining implementation details will be specified against the contracts above.

## References

- [Dev Container Features](https://containers.dev/implementors/features/)
- [Dev Container CLI](https://github.com/devcontainers/cli)
- [EditorConfig](https://editorconfig.org/)
- [OpenCode configuration](https://opencode.ai/docs/config/)


# Inline Feedback

Too much to type into Github, here's a few pieces of feedback to incorporate:

## Desirata

As I'm thinking more deeply, the following properties are desired.

* Fast, offline-friendly environment creation
* Spawning agents in isolated environments
  - We'll assume agents are building code and so they should each have their
    own copy
* Reproducibility of code
  - All prerequisites of code correctness
* Isolation of agent testing / runtime environments
  - We don't want them to stomp on each other's work, so sharing of resources
    should be made explicit.
  - I'm thinking channel-based Unix domain sockets could be a good communication
    primitive
* Efficiency of runtime environments
  - Sharing resources is more efficient, how do we share the most amount of
    resources while avoiding data races
  - A major question/risk for the project: is Docker's containerization too
    heavyweight to achieve good efficiency.
  - Images should only be rebuilt as needed so I'm imagining a temporary
    runtime container installation of prospective packages would be a useful
    feature
* The security risk of privelege escalation
  - I should define a security model up front. I don't want agents running
    on my machine
  - A major front of entry is moving from container to host. Spawning host
    agents should be made explicit and done with great care. Prefer an easy
    pathway for explicitly sharing the minimum amount of data.
  - I like how opencode gives file permission to files within workspace,
    and asks permission for files outside.
  - Generally, I think we want to leverage Linux and Docker's security models
    as much as possible.
  - I'm thinking an interface to create new users and
    groups could be helpful for operating a swarm...



## Main Issue

The architecture is still to loose with certain terminology. I will insist
upon a strict separation of user-facing concepts in
`# Dotfiles architecture` from the internal concepts in the
`# Implementation` sections.

For example, session is a concept from `tmux` (implementation) that is
interspersed in the architecture section. Sitting on top of the behavior of
`tmux` (attaching and detaching to a remote serer) beckons for the
`session` concept to be integrated into `dotfiles`. The number of concepts that
native to `dotfiles` should be actively limited to limit complexity. Maximally
orthogonal concepts help.

Relatedly, please make the document more concise.

