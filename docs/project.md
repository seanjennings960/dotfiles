# Dotfiles Roadmap

## Goal

The goal of this project are twofold:
1. Develop a terminal-based custom IDE for interactive, reproducible programming
2. Codify and improve my software development processes.

With this repository being developed at the height of the AI rush, my sentiment 
is that our desire for a rapid acceleration in coding development speed has
outstripped our patience to understand the code itself. This project bridges that
gap by putting the developer in a position to explore, understand, and edit
agentically-generated code.




I want to bring my terminal-first workflow to a new machine or an existing
project devcontainer, then use it to reconnect to work on remote machines.
The core is tmux, Neovim, a shell, and OpenCode, with Ghostty on my Mac.

Dotfiles should supply useful, versioned defaults. Projects should be able to
choose their own runtimes, checkers, and settings, and I should be able to see
which ones are active.

Today this repository has personal configuration, installation scripts, and an
Ubuntu 24.04 devcontainer. The Neovim setup needs consolidation. The Feature and
`dev` command below are planned.

## Approach



Package the environment as a versioned Dev Container Feature, then add a small
Python `dev` launcher installed through Homebrew. Start with Ubuntu 24.04 on
`arm64`, use existing project conventions and component state, and expand after
testing. The [architecture](architecture.md) describes how the pieces fit together.

## Next Steps

### 1. Make the existing workflow reliable

- Consolidate Vim settings into a working Neovim setup. Keep plugins that
  support capabilities I use and remove obsolete configuration.
- Start with Bash; try Zsh before choosing the supported shell. Verify path and
  Git-branch completion, startup behavior, tmux bindings, and clipboard behavior.
- Make activation work for a fresh non-root home and repeated runs, preserve
  existing configuration, and report failures accurately.
- Supply Python, Ruff, and Pyright with their execution dependencies. Check
  editing, linting, formatting, and type checking both with defaults and with a
  project's own Python environment and rules.
- Add this repository's development dependencies and a documented test command.
  Use isolated homes and workspaces for integration tests, including simulated
  shell/editor input. Update the README to match the working setup.

**Done when:** I can activate twice in a clean Ubuntu environment, edit and check
Python, complete a Git branch, and use the intended tmux bindings. Tests cover
failed installs, repeated activation, failed `cd`, and tmux prefix forwarding,
and confirm project settings take effect.

### 2. Package the environment

- Turn the working baseline into a versioned Dev Container Feature, installed
  for the configured development user.
- Try it in two existing Python projects with different environments and rules.
  Cover image/Dockerfile and Compose setups, project setup hooks, and projects
  with and without lockfiles using a tested Dev Container CLI version.
- Preserve Neovim undo history across container recreation using persistent
  storage. Distinguish recovering saved application state from keeping processes
  running.

**Done when:** repeated setup and rebuilds leave shared project configuration
unchanged, the expected checkers run after project setup, and a new Neovim process
can undo a known saved edit after recreation.

### 3. Add the host launcher

Implement this proposed interface using the same tested workflow:

```text
dev                  Launch or reuse the environment and attach to tmux
dev exec <command>   Run a command in the project environment
dev rebuild          Rebuild/recreate the environment and enter it
dev tooling          Show active executables, versions, and configuration sources
```

Keep personal Feature selection outside the project. Reuse existing container
and session metadata instead of maintaining a second registry.

**Done when:** I can install through Homebrew, launch either test project from my
Mac, reconnect from a fresh `dev` process, and inspect selections that match the
commands actually run. An unrelated active virtual environment must not affect
the host launcher.

## Later

- Add Rust and Julia using the same default/project selection conventions.
- Reconnect to persistent remote work through SSH and tmux. Investigate OpenCode
  plugins, its server API, and existing integrations before building coordination.
- Support native macOS workflows and run their tests on a Mac. Consider a Rust
  CLI only if the implementation needs it; add build or cross-compilation
  dependencies when required.
- Coordinate independent agent tasks through one branch/worktree and session per
  task, returning commits or pull requests. Phone and voice clients can follow.
- Investigate GitHub authentication and a reusable PR skill alongside a security
  review when implementing credential and remote integrations.

Choose detailed schemas, UI indicators, and broader platform support as these
steps produce concrete requirements.
