# Dotfiles Architecture

This is the planned design. Delivery order and completion checks are in the
[roadmap](project.md).


## High-level Design

`dotfiles` is a TUI application, focused on human-agent collaborative software
development.  It provides a Python-, `click`-based CLI called `dev` which
orchestrates a number of developer tools.

The first target platform is MacOS installation via `homebrew`. After
installing the CLI with
```
brew install dotfiles
```
the TUI can be started with the argument-free `dev` command, which is an
alias for `dev enter host`. 

`dev` makes opinionated decisions about toolset to ensure a smooth integration.
Integration tests autonomously verify the interactions between components by
simulating keystrokes input to a shell process.

`dev` composes the following submodules (`click` subcommands):
* `dev env` -- Report active environment, change between them
* `dev tools` -- Manage the tools attached to project: install, upgrade,
  and remove
* 

## Features


* Continuous Integration and Review
* Cost-Efficient, Reproducible, Isolated Environments
* Observable Agentic Execution
* Keyboard-based Code Editing and Navigation
* Integrated Static Analysis tooling


### Continuous Integration Workflow

Coninuous Integration (CI) is a software development practice which aims to
enable rapid software iteration while ensuring quality via a testing-enforced
integration policy. It is a core feature of code hosting providers such as
Github.

Human review of agentic code and behavior is a major goal of the IDE (it's 
vital to maintain an understanding of generated codebases!). Therefore, another
key feature of this project is continuous review (CR). We'll leverage Github's
web interface for human review of code, with `opencode`'s in-app diff viewer
is another contender.

An important part of the review process is a question of transparency. Github's
PR history serves as a auditable record of design decisions and development 
history. `opencode` session histories will be preserved to enhance the
traceability.



### Environment

`dev` supports cost-efficient, reproducible, and isolated environments. 

A dev environment contains all the information needed to reproducibly compile
and run a piece of software. may have binaries
Each environment has a type: either host or docker. available The environment type can
with installed executables 

`dev` manages the **active environment**, which can entered and exited.
`dev env` displays the current environment status.

`dev env` manages installation, upgrade, and removal of install developer
tools.


### Tools

Subcommand:

`dev tools`

lists installed language toolchains.

A tool is a versioned executable and a toolchain is a labeled set of tools.

`dev tools` handles tool versioning by delegating to selected package manager.
We'll start with `apt-get`.

### Language toolchains

Subcommand:

`dev languages`

lists installed language toolchains.

A language toolchain is a toolchain with special meaning to
`nvim` and `opencode`. For example,
* Language Interpreter: Python 3.12
* Linter: Flake8
* Static Analysis: Pyright
* Toolchain manager: hatch

`dev` manages `nvim` and `opencode`'s LSP integration to manage active and
inactive toolchains.

`dev` ships with a set of default toolchains (configurable via feature flags),
but also supports project overrides.





The set of all tools, the "toolset", is packaged as a `devcontainer` [feature](
https://containers.dev/implementors/features/), 


## Implementation

The IDE is built on a variety of existing technologies:
* `tmux`: a terminal multiplexer which allows a developer to split their screen
  and navigate multiple terminals
* `zsh`: an enhanced shell interpreter with improved developer interactivity
* `opencode`: an tool for agent-based coding development
* `nvim`: a keyboard-focused text editor
* `devcontainer`: a technology for connecting developer editors to docker
containers


# Agentic Description

## Components

| Component | Responsibility |
| --- | --- |
| Host | Ghostty or another terminal, Docker, and the Dev Container CLI. Homebrew installs `dev` with its own Python runtime. |
| Personal Feature | tmux, shell, Neovim, OpenCode, personal configuration, and default language runtimes and checkers. Python, Ruff, and Pyright come first. |
| Project | Base image, application dependencies, build/test commands, and overrides to the personal defaults. |
| `dev` | Apply personal launch options, connect to environments and tmux, run commands, and inspect active tooling. |

Keep `dev` a thin wrapper. Applications resolve their own configuration and own
their state; Docker and tmux already provide environment and session metadata.

## Launch Flow

1. Read the project's devcontainer configuration and the user's personal Feature
   selection. Personal launch options live outside the project.
2. Call `devcontainer up` with `--additional-features` to add the selected Feature
   to the image/Dockerfile or Compose development service. Preserve project pins
   and leave shared configuration and lockfiles unchanged.
3. Activate defaults for the configured development user, with writable
   configuration and state directories. Repeated activation must preserve
   existing configuration and report failures.
4. Wait for the required project setup, then use `devcontainer exec` to attach to
   tmux or run the requested command. Resolve project tooling when it is used,
   so dependencies installed by setup hooks are available.

The Feature installs system dependencies as root; usable configuration and
application data belong to the development user.

## Defaults and Project Overrides

Keep bundled runtimes and checkers separate from project environments. Use each
component's existing resolution rules: `.editorconfig` for editor policy,
checker configuration such as `pyproject.toml`, project language environments,
and OpenCode's personal/project configuration. Merge only where that component
supports merging.

For example, a project can use its `.venv` and Ruff rules from `pyproject.toml`
while retaining the bundled Ruff executable. Interpreter selection, checker
selection, and code policy are independent choices.

Neovim, OpenCode, and terminal checks should use the intended selections.
`dev tooling` reports actual executable paths, versions, environments, working
directories, and relevant settings sources, including disabled or unavailable
selections. A configuration file's presence alone is not evidence of an override.
Inspection should use the applications' resolution results rather than build a
second resolver. Add a custom command/override format only when a real project
cannot be supported through existing conventions.

## State and Reconnection

- Docker owns containers and persistent volumes; tmux owns running sessions.
- Neovim owns undo files; OpenCode owns conversations and its generated data.
  Store writable data outside packaged configuration.
- `dev` discovers environments through existing metadata and arranges stable
  storage for the workspace and development user. Any discovery cache is
  disposable; a fresh process can reconnect and reattach storage after recreation.

For persistent undo, configure Neovim to write to a state directory backed by
persistent storage. Reattach it after recreation so a new editor process can
undo a saved edit. A container restart or rebuild ends running processes;
persistent files recover history, while tmux supports client disconnection as
long as its execution environment stays running.

## Updates and Platforms

- A new Feature release or packaged executable/configuration requires rebuilding
  the derived image and recreating the container.
- Project settings or supported external personal overrides require reloading
  the affected application. Mount changes require container recreation.
- Pin managed runtimes, executables, plugins, and Feature dependencies, including
  transitive dependencies. Record installed versions and use an exact Feature
  release or digest with a tested Dev Container CLI version.
- Start with Ubuntu 24.04 on `linux/arm64`. Docker Desktop runs Linux in a VM on
  macOS; `amd64` containers on Apple Silicon use emulation. Report emulated tests
  separately, and run native macOS workflows and tests on a Mac.

## References

- [Dev Container Features](https://containers.dev/implementors/features/)
- [Dev Container CLI](https://github.com/devcontainers/cli)
- [EditorConfig](https://editorconfig.org/)
- [OpenCode configuration](https://opencode.ai/docs/config/)
