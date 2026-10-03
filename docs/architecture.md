# Dotfiles architecture

`dotfiles` provides a terminal-first workspace for human-agent development, with
keyboard-based editing, integrated code checks, and observable agent execution.
This is the planned design. User-facing contracts are below; backend mechanisms
belong in Implementation. Delivery milestones are in the [roadmap](project.md).

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

Bare `dev` enters the host for human work. Container entry is explicit and uses
project environment configuration subject to the security contract. Missing
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
dev                                    Enter or reconnect to human host work
dev env                                Show the environment and workspace
dev env enter host                     Enter or reconnect to host work
dev env enter container                Prepare and enter a project container
dev env rebuild                        Rebuild/recreate the container and enter it
dev agent start                        Copy the workspace and start an isolated agent
dev tools                              Show desired and installed personal tools
dev tools install [<tool>]              Install defaults or a selected tool
dev tools install --temporary <tool>    Try a tool in the current container
dev tools upgrade                      Upgrade personal defaults
dev tools remove <tool>                Remove a personally managed tool
dev languages                          Show enabled and effective language support
dev exec <command>                     Run a command in the current environment
```

Agent selection and authorization options remain to be specified.

# Implementation

## Components

| Component | Responsibility |
| --- | --- |
| Python and Click | The macOS host launcher, installed with `brew install dotfiles` and its own Python runtime. Personal tools install separately. |
| Ghostty or another terminal | Host terminal input and rendering. |
| tmux | Layout, keyboard navigation, running sessions, attachment and detachment. |
| Shell | Interactive execution and completion; evaluate Zsh after a Bash baseline. |
| Neovim and OpenCode | Editing, code checks, agent execution, diff review, and their own undo/conversation state. |
| Docker and Dev Container CLI | Container execution, image caching, volumes, limits, and project setup. |
| Personal Dev Container Feature | Versioned packaging of personal tools and defaults outside project configuration. |

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

## References

- [Dev Container Features](https://containers.dev/implementors/features/)
- [Dev Container CLI](https://github.com/devcontainers/cli)
- [EditorConfig](https://editorconfig.org/)
- [OpenCode configuration](https://opencode.ai/docs/config/)
