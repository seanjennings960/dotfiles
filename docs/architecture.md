# Dotfiles Architecture

This is the planned design. Delivery order and completion checks are in the
[roadmap](project.md).

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
