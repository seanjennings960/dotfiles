# Dotfiles Architecture

This document describes the intended design. Delivery order and acceptance
criteria live in the [Project Roadmap](project.md).

## Defaults, Overrides, and Ownership

**Dotfiles provides a working, versioned default environment. Projects override
the parts they specify, and the effective configuration and its sources are
visible to the developer.**

| Component | Responsibility |
| --- | --- |
| Host setup | Provide the terminal, Docker runtime, Dev Container CLI, and dependencies needed to run `dev`. |
| Personal Feature | Provide tmux, the supported shell, Neovim, OpenCode, personal configuration, extensions, and language bundles. |
| Language bundle | Provide a default language runtime/toolchain, checkers, formatters, language servers, and their execution dependencies. |
| Project environment and configuration | Provide application dependencies, build/test commands, and any overrides to default runtimes, executables, or code policy. |
| `dev` CLI | Apply personal launch configuration, discover and connect environments and sessions, and expose active tooling selections. |
| Editor and agent harness | Manage their own configuration resolution and application state. |
| Integration layer | Own only durable cross-component information that cannot be recovered from existing component metadata. |

For example, a project can use the bundled Ruff executable while supplying its
own rules in `pyproject.toml`. Another project can select its own Ruff version
and Python environment. An unconfigured workspace should still have useful
Python editing, linting, formatting, and type checking.

This repository is also a project. Its development environment must supply the
dependencies required to build, test, package, and eventually cross-compile
`dev` itself.

## Execution Platforms and Packaging

The initial `dev` implementation is a host-side Python CLI targeting
Docker-backed environments. On macOS it will be installed through Homebrew,
including the Python runtime needed by the CLI; launching must not depend on a
project virtual environment. The initial implementation will migrate to Rust
when adding native environment support, retaining its user-facing contracts.

The personal configuration selects language bundles and an exact Feature
release or digest. The Feature's final name remains an implementation decision.
Language support starts with Python, followed by Rust and Julia; runtimes and
toolchains are included in those bundles.

Initial container support targets Debian/Ubuntu Linux on `amd64` and `arm64`.
Ubuntu 24.04 is the existing baseline; the first release must identify the exact
Debian/Ubuntu versions it has tested before declaring support for them.

Apple Silicon is ARM64. Docker Desktop runs Linux containers in a Linux VM on
macOS. A multi-platform image supplies separate `linux/amd64` and `linux/arm64`
variants; running an AMD64 variant on ARM64 requires emulation. The Feature must
select binaries and dependencies for the container's actual architecture.
Native and emulated test results should be distinguishable.

Native macOS execution requires a Mac or macOS runner. Linux containers can
orchestrate that work, but a Linux container does not supply the macOS runtime
or Xcode. Cross-compilation produces target artifacts; native integration tests
establish whether those artifacts and the workflow work on their target hosts.

### Release Reproducibility

Each release must pin its managed runtimes, toolchains, executables, editor and
OpenCode extensions, and Feature dependencies. Use exact versions or commits,
artifact checksums, and Feature digests where appropriate. Transitive dependency
resolution must be reproducible as well.

OS-package versions require a distribution-specific pinning strategy, including
snapshot repositories where needed to retain the selected versions. A moving
major-version Feature tag is a release channel, not an exact pin. Record the
installed versions and test them against the release's dependency selections.

Projects independently select their base images and application dependencies.
Project overrides are reported as overrides to the released baseline rather
than changing what that baseline means.

## Personal Devcontainer Injection

`dev` uses the Dev Container CLI's `--additional-features` mechanism to apply the
personal Feature to a project's existing image, Dockerfile, or Compose setup.
For Compose, it applies to the designated development service.

Personal Feature selection and options live outside the project, in a launcher
configuration whose schema is still to be defined. This is user configuration,
not a separate operational registry or a standard devcontainer override file.

The underlying operations are `devcontainer up` with the selected additional
Feature, followed by `devcontainer exec` to enter tmux or run a command. `dev`
provides the launch, execution, rebuild, and inspection interface described in
the roadmap.

Use the project's lockfile when present and validate frozen-lockfile behavior
with the pinned Dev Container CLI version. For a project without a lockfile,
avoid creating one during personal injection. Test both cases, including the
injected Feature's transitive dependencies, so personal setup preserves project
pins and does not modify shared configuration.

## Installation, Activation, and Selection

These stages have different responsibilities:

1. **Image build:** install pinned executables, runtimes, and toolchains, and
   package personal configuration and extensions.
2. **Container creation:** activate configuration for the configured development
   user, composing with existing configuration and making component-owned state
   directories available. Repeated activation should produce the same result.
3. **Application startup/use:** select the effective runtime, executable, working
   directory, and settings after the project's dependency setup has completed.

Feature installation runs as root, but user configuration targets the configured
development user and that user's home. This distinction prevents installing
usable defaults only for root or leaving the development user's state unwritable.

Feature lifecycle commands execute before project commands in the same phase.
For example, the Feature provides Neovim, Pyright, and Ruff; a project setup hook
later creates `.venv` and installs a different Ruff version. The editor and agent
integrations select the project environment when used, rather than permanently
recording a missing executable during Feature setup. `dev` must wait for the
project setup needed by the requested workflow before entering it.

### Applying Changes

| Change | Required action |
| --- | --- |
| Feature release, packaged defaults, binaries, or build-time options | Rebuild the derived image and recreate the container; unchanged image layers can be cached. |
| Project settings or a supported mounted personal override | Reload the affected application or start a new process, according to that component's behavior. |
| Mounts or container-level environment | Recreate the container; rebuilding the image may be unnecessary. |
| Settings read only at application/service startup | Restart that application or service. |

Runtime-editable personal configuration requires an explicitly supported
external location. Editing defaults packaged inside the Feature changes the
release and requires an image rebuild. A container restart is not a universal
configuration-reload mechanism.

## Shell Integration

Bash and Zsh both support command-specific completion, including Git branches.
Bash commonly uses a completion package and command-specific scripts. Zsh offers
richer completion menus, matching, and globbing options; its scripting semantics
differ from Bash. History-based autosuggestions are a separate capability from
Tab completion.

Evaluate both shells during the first milestone, starting from the existing
Bash workflow. The selected baseline must provide reliable completion and
personal keybindings while composing with the project's startup configuration
and environment. The evaluation should identify the dependencies and startup
integration required to make those capabilities repeatable.

## Language Bundles and Project Integration

Use precise names for the different capabilities: executables, editor plugins,
language servers, OpenCode plugins, and agent skills. Here, **diagnostics** means
code errors and warnings reported by checkers or language servers and displayed
in the editor or supplied to the agent.

| Bundle | Proposed baseline |
| --- | --- |
| Python, first | Python runtime, Ruff for linting/formatting, and Pyright for type checking and language-server support, including its runtime dependencies. |
| Rust, next | Rust toolchain, rust-analyzer, rustfmt, Clippy, and compiler checks through Cargo. |
| Julia, next | Julia runtime, LanguageServer.jl, and formatting through JuliaFormatter.jl or the selected equivalent. |

Install managed executables and their dependencies separately from project
environments. A project can select another Python interpreter, Rust toolchain,
Julia environment, executable version, or checker command without modifying the
default installation.

### Configuration Sources

- **`.editorconfig`:** the independent, cross-editor convention for indentation,
  whitespace, and file-format policy. It is not specific to Vim.
- **Checker and formatter configuration:** files such as `pyproject.toml`,
  `ruff.toml`, `pyrightconfig.json`, and `rustfmt.toml`.
- **Runtime and dependency configuration:** project virtual environments,
  `rust-toolchain.toml`, Cargo configuration, and Julia's
  `Project.toml`/`Manifest.toml`.
- **Project commands:** existing Makefiles, package/task configuration, and
  scripts define canonical build, test, lint, and format invocations.
- **OpenCode configuration:** personal defaults in user-global configuration,
  project settings in `opencode.json`/`opencode.jsonc`, extensions in `.opencode/`,
  and project guidance and check commands in `AGENTS.md`.

Use each component's documented resolution rules. Project settings replace
conflicting defaults while unrelated defaults remain active, where the format
supports granular merging. Report explicit disablement and unavailable
project-selected dependencies so the displayed selection matches actual behavior.

OpenCode already provides LSP integration, server discovery, and automatic
downloads for some supported servers. Configure the supported release to use
the managed, pinned executables and account for its server prerequisites and
download behavior. Neovim and OpenCode can use the same server executable while
each manages its own server process. Editor integrations invoke the selected
checker commands or receive language-server findings. CLI checks and application
integrations should agree on runtime and code policy; expose differences in
effective selections.

### Command Overrides

Standard configuration may not describe how to invoke a checker. For example,
packages in a Python monorepo may each have their own virtual environment and
require a wrapper script run from the package directory. The lint rules alone
do not select that wrapper or working directory.

Devcontainer `customizations` supports product-specific namespaces. A namespace
such as `customizations.dev` is a candidate for declarative command selection
and editor settings that existing conventions cannot express. It would need a
defined schema and a consumer that passes the settings to the affected
components; it does not configure Neovim automatically. Finalize this extension
only against a concrete integration case, also accounting for native workspaces
without a devcontainer. Basic adoption should use existing project conventions.

### Visible Overrides

Track executable/runtime selection separately from the source of code settings.
For example:

```text
Python · project overrides: Ruff rules, Python environment

Ruff executable:    dotfiles default (resolved path and version)
Ruff rules:         project pyproject.toml
Pyright executable: dotfiles default (resolved path and version)
Python environment: project .venv
```

The proposed `dev tooling` command exposes paths, versions, relevant configuration
sources, and effective changes. Neovim should show a compact persistent
indicator with a detailed inspection view. OpenCode should present active
overrides at session startup; investigate its UI extension capabilities for a
persistent indicator.

Attribute only configuration that actually affects the current file or command.
Track sources during resolution: the presence of `pyproject.toml` or inspection
of the final merged settings alone does not explain which values changed.
Derived inspection information should be recomputed from component configuration
and metadata, not require a durable `dev` database.

## Runtime State and Minimal Orchestration State

Each component manages its own runtime state. `dev` discovers and connects
components, provides access to their persistent storage, and retains only the
durable information required by its integrations. Derived orchestration state
is reconstructable.

| State or information | Owner and persistence |
| --- | --- |
| Editor undo history and saved editor sessions | Neovim manages its files in its configured state directories. |
| Conversations and agent sessions | OpenCode manages its application data using its supported storage mechanisms. |
| Running terminal sessions | tmux manages processes and sessions on the execution host. |
| Containers and volumes | Docker maintains them and exposes discovery metadata. |
| Feature selection and launch options | User configuration, read and applied by `dev`. |
| Necessary cross-component records | The responsible integration, with an explicit purpose and lifecycle. |

Prefer Docker metadata for container discovery and tmux/OpenCode interfaces for
session discovery. Any derived cache must be disposable. A fresh `dev` process
should recover the same environment view without importing an independent
registry of containers or component sessions.

### Example: Neovim Persistent Undo History

The Feature configures persistent undo and a directory such as
`~/.local/state/nvim/undo/`. Neovim decides when and how to write its undo files.
For container execution, `dev` arranges stable persistent storage at the
configured location for the development user; Docker owns the volume. Native
execution uses a persistent host directory.

1. Edit and save a workspace file in Neovim.
2. Neovim writes its undo history to its configured state directory.
3. Recreate the container and reattach that storage at the expected location.
4. Open the same file with unchanged saved contents and verify that Undo can
   restore the earlier contents.

The workspace stores the current file, while Neovim's state stores the editing
history. Recreating the container starts a new editor process; persisted files
let that process recover history. Choosing and attaching the storage does not
make `dev` the owner of the undo records.

### Integration Records

A future dispatch integration may need a durable relationship between a task,
execution host, worktree, agent session, and result. First investigate whether
existing component metadata can represent or reconstruct it. Persist new
integration records only where that is insufficient, documenting their owner,
storage location, recovery behavior, and lifecycle.

GitHub authentication is reserved for a separate future inquiry, coordinated
with an application-wide security audit. Persistent editor history is the
initial state-management example.

## Remote Sessions and Native Work

Processes stay on their execution host. SSH reconnects the client, and tmux
maintains running terminal sessions there. Container sessions survive client
disconnects while the container and processes keep running; a rebuild or
container restart ends those processes. Persisted application files can support
recovery, but do not transfer or preserve running processes.

Investigate OpenCode plugins for lifecycle events and notifications, its server
API/SDK for discovery and control, and existing SSH/tmux integration programs
before designing integration-specific state. Worktrees isolate tasks on a shared
host; separate clones do so across hosts. Native project builds execute on
appropriate hosts and report their source revision, toolchain, results, and
artifacts.

## References

- [Dev Container Feature specification](https://containers.dev/implementors/features/)
- [Devcontainer metadata and customizations](https://containers.dev/implementors/json_reference/)
- [Dev Container CLI](https://github.com/devcontainers/cli)
- [Feature integration testing](https://github.com/devcontainers/cli/blob/main/docs/features/test.md)
- [Docker multi-platform builds](https://docs.docker.com/build/building/multi-platform/)
- [EditorConfig](https://editorconfig.org/)
- [Neovim RPC and input APIs](https://neovim.io/doc/user/api/)
- [OpenCode configuration layering](https://opencode.ai/docs/config/#locations)
- [OpenCode LSP integration](https://opencode.ai/docs/lsp/)
- [OpenCode plugins](https://opencode.ai/docs/plugins/)
- [OpenCode server API](https://opencode.ai/docs/server/)
