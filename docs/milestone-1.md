# Milestone 1 execution plan

Establish a reliable Ubuntu 24.04 ARM64 terminal workflow. The roadmap's first
milestone is delivered as six independently reviewed steps, followed by an
end-to-end acceptance run.

1. **Test harness and toolchain:** isolated pytest/pexpect fixtures, `make test`,
   Python 3.12, pinned Neovim, Ruff, Pyright with its Node runtime, and OpenCode.
2. **Activation:** one installer, idempotent managed shell source blocks, safe
   conflict handling, accurate failures, and user-owned writable state.
3. **Shells:** reliable Bash startup/completion and failed `cd` semantics; a Zsh
   setup that can be compared through the same exercises.
4. **tmux:** prefix forwarding, intended bindings, pane-specific logical paths,
   and clipboard escape sequences suitable for a headless container.
5. **Neovim:** a working startup configuration, familiar editing behavior,
   EditorConfig, state directories, and a guide to incremental plugin trials.
6. **Python:** Ruff lint/format and Pyright integration, with behavioral tests
   proving default/project environment, executable, and rule selections.

Complete and verify step 1 first. Develop steps 2–6 in separate worktrees on top
of that baseline, each with its own PR. Keep file ownership distinct: activation
owns installer files, shells own shell files, tmux owns its configuration/helper,
Neovim owns its core configuration, and Python owns its editor integration module.
Cross-step tests must also pass with the PRs combined before milestone acceptance.

## Verification boundaries

Automated checks use subprocesses, pseudo-terminals, isolated tmux servers, and
headless Neovim. They assert exit statuses, files, application state, actual
diagnostics, selected executables, and received input. They do not require desktop
control or provider credentials.

The devcontainer runs with an init process to reap application subprocesses.
Timed-out subprocess tests terminate their private process groups, including
language servers that would otherwise keep captured output streams open.

The final manual checklist covers Ghostty rendering, actual Mac clipboard
copy/paste, Bash-versus-Zsh preference, and whether each plugin improves the
workflow. Emitted clipboard sequences alone do not prove host clipboard delivery.

## Completion run

As a non-root user in a fresh Ubuntu 24.04 ARM64 environment:

- Prepare recorded plugins and activate twice.
- Complete a path and Git branch with Tab.
- Exercise tmux splits, windows, navigation, resizing, and prefix forwarding.
- Edit/save Python, format with Ruff, and observe lint and Pyright type errors.
- Repeat with project-specific environments and settings, showing actual selections.
- Launch the installed OpenCode executable; confirm writable user configuration/state.
- Run `make test`, then complete the manual terminal/clipboard checks.

Update the README with verified activation, mappings, selection rules, inspection
commands, and the test command. Plugin trials are incremental rather than a bulk
replacement of the current plugin collection.
