# Dotfiles roadmap

## Goal

This project has two goals:
1. Develop a terminal-based custom IDE for interactive, reproducible programming.
2. Codify and improve my software development processes.

I want to explore, understand, and edit agent-generated code, rather than let
coding speed outstrip my understanding of it. I also want to bring my
terminal-first workflow to a new machine or an existing project devcontainer,
then reconnect to work on remote machines. The core is tmux, Neovim, a shell,
and OpenCode, with Ghostty on my Mac.

Dotfiles should supply useful, versioned defaults. Projects choose their own
runtimes, checkers, and settings, and I should be able to see which ones are
active. This baseline has a host launcher, offline configuration activation,
repository checks, and an Ubuntu 24.04 devcontainer. Tool lifecycle management
and the Dev Container Feature remain planned.

## Approach

Build the launcher first, then deliver the personal tools and integrations
through it. Use Python and Click with a runtime environment separate from project
environments. Initially develop and verify in this repository's Ubuntu 24.04
`linux/arm64` devcontainer with Python 3.12 as the non-root `vscode` user. Host
mode there means the container running the launcher. macOS installation,
Homebrew packaging, and macOS installer adapters follow in a future PR. Add
managed container entry after the initial workflow works.

The [architecture](architecture.md) defines the workspace, environment, and
personal toolset contracts. This plan defines the delivery steps. Keep personal
selections outside shared project configuration, let applications resolve their
own settings, and use tmux and Docker metadata for their respective lifecycles.

`dev test` is the entry point for this repository's automated checks. Each feature
PR adds its checks to that interface. Projects continue to own their test commands,
which can run through `dev exec`.

## Consolidation order

Incorporate the existing implementations and findings through five PRs. Preserve
their behavioral tests and document the reasoning when implementations overlap.

| Group | Source PRs | Delivery |
| --- | --- | --- |
| Host workflow and repeatable setup | #14, #15, #6 | Launcher, offline activation, repository checks, and GitHub review guidance |
| Reliable shell behavior | #16, #9 | Startup, executable precedence, completion, directory changes, and Julia PATH handling |
| Reliable tmux operations | #18, #8, #3 | Native creation with scoped logical-path handling, navigation, clipboard, and window moves |
| Working Neovim Python environment | #17, #19 | One production editor startup, project policy, Python tools, and plugin evaluation |
| Understanding shell execution | #22 | Five-chapter tutorial, workspace example, and terminal demonstrations |

The first group is implemented in this baseline. Shell behavior precedes tmux
integration. Editor and learning work can follow independently. Each feature
tests normal configured startup in isolated homes and workspaces. Update the
README as commands become available.

### 1. Host workflow and repeatable setup

- Add the Python launcher with Click commands and explicit devcontainer setup.
  Give it its own runtime environment and report missing personal tools without
  installing them during entry. An active project virtual environment must not
  affect the launcher.
- Discover the enclosing Git worktree, treating each worktree as a distinct
  workspace. Support an explicit workspace path and invocation outside a project.
  Preserve the invocation directory when it is inside the workspace.
- Implement the initial host commands below. Bare `dev` enters human host work
  and reconnects through local tmux session metadata. `dev exec` works without
  interactive entry and preserves arguments, directory, streams, exit status,
  and terminal behavior. Environment context stays local to the invocation.
- Add locked development dependencies and a thin `dev test` runner. Initially
  run launcher tests, forward test-runner arguments, and return failures through
  the exit status. Add fixtures for isolated homes, workspaces, and terminal input
  as needed. The initial runner needs neither the full toolset nor Docker.

```text
dev                         Enter or reconnect to human host work
dev env                     Show the host environment and workspace
dev env enter host          Enter or reconnect to human host work
dev exec <command>           Run a command in the current environment
dev activate                Apply personal configuration offline
dev test [<test args>]       Run this repository's automated checks
```

Done when explicit setup in the Ubuntu devcontainer makes production `dev test`
work as non-root `vscode`, I can reconnect from a fresh launcher, and inspection
reports the workspace and directory actually used. `dev test` covers discovery,
command forwarding, terminal behavior, reconnection, and failure reporting on
Linux ARM64. Unsupported managed-container requests fail without executing in
host mode. Docker builds the development environment; entry and the runner do
not require Docker access or the full personal toolset.

Activation preserves user configuration, rejects conflicts before mutation, and
rolls back write failures. Both legacy installer scripts delegate to `dev activate`.
Application state stays outside configuration source. Tests activate twice and
then enter and reconnect through the production launcher. OpenCode discovery of
the PR skill has an explicit optional check; authentication guidance and review
steps live in the README and skill.

### 2. Reliable shell behavior

- Make Bash the working baseline and evaluate Zsh before choosing the supported
  shell. Load personal defaults through the baseline activation, preserving
  user startup files and avoiding installation or network access during startup.
- Preserve project and virtual-environment executable precedence. Verify login,
  non-login, interactive, and noninteractive behavior, including repeated sourcing.
- Track each tmux pane's working directory after successful changes. Preserve
  failed `cd` status and directory state; a bookkeeping failure must not turn a
  successful directory change into a failure.
- Add real terminal-input checks for path and Git-branch completion, including
  spaces and logical symlink paths. Document the Bash/Zsh comparison for manual
  evaluation on the host terminal.
- Incorporate #9's user-managed Julia path with home-relative, Bash/Zsh-compatible
  handling that preserves active project executable precedence.

Done when shells entered through `dev` use the expected project executables,
complete paths and Git branches, and preserve user startup behavior. `dev test`
covers failed `cd`, repeated startup, and independent pane directories.

### 3. Reliable tmux operations

- Combine #8's native creation baseline with #18's logical-path requirements.
  Keep the helper limited to behavior native tmux does not supply.
- Repair prefix forwarding, layout, split, and window bindings using the shell
  directory contract. New panes and windows inherit the source pane's directory,
  including spaces and logical symlink paths. Avoid global directory handoffs.
- Incorporate #3's selected-window moves with launcher session identity, including
  moving every window out of the source session.
- Discover sessions through tmux metadata. Reconnection preserves processes and
  directories, and detaching leaves them running. Test independent workspaces and
  source panes while another session is active.
- Exercise bindings through an attached terminal, including copy/paste and
  emitted clipboard sequences. Verify host clipboard delivery manually.

Done when fresh launcher processes reconnect to the intended work, concurrent
splits preserve directories, and window moves retain running processes. Leaving
one shell must not destroy other work.

### 4. Working Neovim Python environment

- Consolidate Vim settings into one working Neovim startup loaded by normal
  activation. Keep useful, pinned plugins and remove obsolete configuration;
  startup must not download or update plugins.
- Use native EditorConfig and Neovim settings resolution. Preserve project code
  policy and support explicit personal plugin trials without rewriting projects.
- Store undo, swap, and backup data outside packaged configuration. Prepare for
  persistent storage scoped to the workspace and user when container recreation
  is added.
- Test actual editing, saving, mappings, project indentation, and undo from a new
  Neovim process through the production startup. Check terminal rendering and
  system clipboard delivery manually on Ghostty.

Done when Neovim launched in the `dev` workspace uses the intended configuration,
project indentation takes effect, and a new process can undo a known saved edit.
`dev test` exercises normal startup and reports missing plugins or broken local
configuration.

Python integration belongs in the same PR and uses that production startup:

- Provision personal Python, Ruff, and Pyright explicitly with their execution
  dependencies. Keep runtime, formatter, diagnostics, and intelligence independent.
- Add Python editing, linting, formatting, and type checking to the normal
  Neovim startup. Use application resolution for project environments
  and checker settings; do not introduce a second configuration resolver.
- Preserve #19's ALE/Pyright settings finding and its narrowly scoped bridge.
  Verify completion, hover, definition, and that unrelated clients stay untouched.
- Test personal defaults and projects that choose their own Python, checker,
  and code policy independently. Unavailable project-selected tools must fail
  visibly; disabling an integration must preserve shared tools and project files.

Done when editing, linting, formatting, and type checking work with defaults and
with two Python projects that choose different environments and rules. `dev test`
uses the combined production setup to check project overrides, unavailable tools,
and disabled integrations.

### 5. Understanding shell execution

Keep #22's context, arguments, execution, and interaction model, worked exercises,
and workspace example. The terminal companion displays exact source, output,
errors, and status for fixed demonstrations in disposable environments. Share
explanations through chapter links rather than repeating them in each README.

## Tool management and inspection follow-up

After consolidating existing code, implement `dev tools`, `dev tools install`,
`dev tools upgrade`, and `dev tools remove`. Store exact selections outside
projects and track installation ownership. Report unavailable versions, conflicts,
and individual failures. Removal preserves shared dependencies; failed upgrades
leave an accurate report. Start with Ubuntu installers and retain offline
activation as a separate operation. Add macOS adapters and launcher packaging later.

Implement `dev languages` inspection of desired and effective tools, executable
paths, runtimes, settings sources, and differences between editor, terminal, and
agent checks. Report unresolved choices as unresolved. Test ownership-aware removal,
upgrade failures, disabled integrations, and unavailable project-selected tools
without modifying project dependencies or lockfiles.

## Package the toolset and add container environments

After the host baseline, package the selected tools and defaults as a versioned
Dev Container Feature and add `dev env enter container` and `dev env rebuild`.
Extend `dev exec` and inspection to the invoking container environment.

- Keep Feature selection outside shared project configuration. Pin its release
  or digest and the tested Dev Container CLI version. Validate project hooks,
  mounts, and privileges against user grants, including separate authorization
  for host-side hooks. Failed or missing container setup must stop execution.
- Test image/Dockerfile and Compose projects, setup hooks, and projects with and
  without lockfiles. Activate for the configured development user and resolve
  tools after project setup. Discover containers through Docker metadata.
- Persist Neovim undo and OpenCode history in storage scoped to the workspace and
  user. Rebuild ends running processes but retains workspace files and saved state;
  reconnecting to a live environment preserves its processes.
- Record code revision, platform, base environment, dependency and configuration
  inputs, commands, and required services. Reuse compatible builds and verify
  offline creation with cached prerequisites; report missing or unpinned inputs.
- Add temporary container installations with visible runtime drift and explicit
  promotion into the personal or project specification. Recreation discards
  temporary packages. Keep privileged installation in trusted, constrained steps.
- Measure cached startup, per-environment memory, and concurrent test throughput
  before choosing resource budgets or committing to swarm scale. Apply resource
  limits to each environment.

Done when either Python project can launch, reconnect, and rebuild without
changing shared configuration or lockfiles. `dev test` covers failed setup without
host fallback, cached offline creation, saved undo/history recovery, and discarded
temporary installs. Run native macOS checks on a Mac and report emulation separately.

## Later

- Implement `dev agent start` with independent workspace copies, writable
  application state, and build/test resources. Enforce the architecture's
  non-root runtime, filesystem, privilege, and network restrictions before
  enabling launches. Test that concurrent agents cannot modify each other's
  source or state and cannot reach ungranted host resources. Human host entry
  does not authorize host-agent execution.
- Keep agent changes and execution history available for review, linked to the
  starting revision and environment inputs. Return commits or pull requests;
  projects retain ownership of CI and integration policy.
- Reconnect to remote work through SSH and tmux. Investigate OpenCode plugins,
  its server API, and existing integrations before building coordination.
- Add Rust and Julia using the same independent runtime/checker selections.
- Prototype scoped Unix socket channels and user/group provisioning where
  explicitly granted sharing needs them. Share immutable caches read-only and
  require an owner and write-coordination rule for shared mutable resources.
- Extend the GitHub CLI authentication and PR skill workflow when implementing
  credential and remote integrations. Phone and voice clients can follow.
- Consider a Rust CLI only if the implementation needs it. Choose detailed
  schemas, UI indicators, and broader platform support as requirements emerge.
