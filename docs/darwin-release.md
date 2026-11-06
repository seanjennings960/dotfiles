# Darwin packaging release review

## Sources and scope

The release branch was created from `master` at `b8ce5a8`, then the development
packaging series was rebased onto it. The unrelated Hazelnut documentation commit
`52101d9` remains on `dev`, not in this release (follow-up #56). The main checkout's
shared CLI preferences were committed separately and copied into the release.

Both remotes were fetched: `origin`, and
`asus` (`dev@asus:/home/dev/workspaces/devchain`). ASUS's `dotfile_os` branch ends
at `e615e5a`. Its packaging is in `flake.nix`; there is no separate `flake.part`
file or flake-parts conversion in either source.

The net reusable packaging changes from `origin/dotfile_os` at `0c3f9b1` are
integrated without importing historical NixOS/ISO commits. DevOS owns operating
systems, images and machine configuration.

## Semantic diff groups

| Group | Decision |
| --- | --- |
| Pinned Nix/Hatch launcher, wheelhouse, formatter, toolset and configured tmux/Neovim/Zsh | Integrate the `dev` packaging series; it replaces competing runtime provisioning. |
| ASUS x86_64 outputs and baseline OpenCode archive | Integrate alongside ARM64 Darwin/Linux outputs. |
| Explicit Hatch/pip installer selection | Integrate the ASUS fix so sandboxed builds use the fixed-hash wheelhouse. |
| Launcher fallback `PATH` | Correct the prefix regression from `d236047`: project Git/tmux must precede packaged fallbacks. Add an installed-wrapper check. |
| Ghostty/OpenCode configuration artifacts | Keep explicit manual activation. Include the reviewed shared `cli.json` with server config and the existing skill. |
| Legacy home activation, shell/editor runtime features and deeper regressions | Do not revive the old installation layout; retain the relevant next-sprint PRs below. |
| Dev Container Feature/bootstrap | Defer #47 as the successor to #41. |
| Inspection/window-management additions in #43 | Preserve unique code and acceptance expectations in #55, related to #3/#19. |
| Hazelnut, formal models and teaching/agent features | Defer independently; not packaging dependencies. |
| ASUS keybinding-analysis prototype | Defer `e615e5a` in #57; do not adopt its model as a release guarantee. |
| Image-writing tools (`dd`/`pv`) | Defer to the DevOS owner in #59. |
| Other local editor/agent experiments | Preserve branch tips and account for them in #58; exclude generated dependency/compiler state. |

## Superseded PRs

Close these in favor of the consolidated release, without deleting their branches.
Closing does **not** claim that all old runtime features were implemented by Nix.
Their independent remnants have explicit deferred owners.

| PR | Disposition |
| --- | --- |
| #8 | Native pane splitting is already on master through #48. |
| #14 | Old Ubuntu runtime/runner superseded by Nix package checks; extra regressions remain in #28/#29. |
| #26 | Runtime provisioning superseded by Nix/Hatch and the wheelhouse. |
| #27 | Old harness superseded; fixtures preserved for the deferred #28/#29 test ports. |
| #30 | Packaged Zsh covers startup; additional Bash/logical-path scope remains in #16. |
| #31, #32, #33, #35 | Old activation implementation/tests are not the Nix artifact contract; future transactional home activation remains in #15. |
| #36, #37 | Legacy activation/host setup documentation is superseded by the packaging guide. |
| #38 | Historical stack-delivery roadmap is obsolete; independent design work remains in #42. |
| #41 | Competing Feature implementation superseded by deferred #47. |
| #43 | Aggregate setup superseded; unique runtime inspection/window work retained in #55, #3 and #19. |
| #45 | Review-only integration snapshot; launcher already landed, Feature/formal scope remains in #47/#44. |
| #53 | Reusable ASUS packaging integrated; OS/image and experimental check scope deferred. |
| #54 | Replaced by this focused release; Hazelnut documentation deferred in #56. |

## Punted PRs: next sprint

Each remains open with `next-sprint` and the indicated `bug` or `feature` label.
Old stack bases are preserved; rebasing and porting to the current `config/`
layout is part of follow-up work, not evidence of current compatibility.

| PR | Type | Remaining scope |
| --- | --- | --- |
| #3 | feature | New window-management command; reconcile with #55's stable-ID implementation. |
| #9 | bug | Hard-coded Julia installation path and Zsh-only PATH behavior in Bash config. |
| #15 | feature | Transactional, conflict-preserving home activation and rollback. |
| #16 | feature | Bash, optional personal hooks and logical-path bookkeeping beyond packaged Zsh. |
| #17 | feature | External local-config hooks, OSC52 integration and optional plugin trials beyond the packaged editor baseline. |
| #18 | bug | Prefix forwarding, concurrent pane targeting and logical-symlink path preservation. |
| #19 | feature | Pyright, formatting, richer project policy and language-intelligence acceptance. |
| #22 | feature | Zsh tutorial, examples and terminal companion. |
| #23 | feature | Simplify skill and evaluation. |
| #28 | bug | Additional workspace/argv/streams/signals/status regressions; port to the current CLI. |
| #29 | bug | Real-PTY persistence/collision/reconnection regressions; port to packaged tmux. |
| #34 | feature | GitHub PR skill, moved to current config paths with V2 guidance. |
| #39 | feature | OpenCode session-history search and export. |
| #42 | feature | Comprehension-focused architecture and roadmap. |
| #44 | feature | Lean creation-policy prototype and backend integration. |
| #47 | feature | Nix bootstrap, editable installation and reusable Dev Container Feature. |
| #51 | feature | Formal editor/deployment models, proofs and guide follow-up. |

Source-only follow-ups are #55 (inspection/windows), #56 (Hazelnut), #57 (ASUS
keybindings), #58 (local editor/agent experiments), and #59 (DevOS image tools).
All are explicitly labeled `feature` and `next-sprint`.

## Worktree and untracked-file cleanup

- Pruned 21 worktree records whose directories no longer exist, after preserving
  their administrative metadata/indexes and the repository refs.
- Preserved the dirty `dotfiles-devchain` and `dotfiles-pop-windows` worktrees,
  including staged changes and dirty plugin submodules; did not force-remove,
  reset, stash or overwrite them. Saved staged/unstaged patches as an extra backup.
- Committed `config/opencode/cli.json` as shared configuration. The Nix artifact
  includes it; OpenCode's actual global configuration remains user-writable.
- Moved untracked `formal/` (only generated `.lake` output) into
  `${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/darwin-finalization/20261106T045322Z/`.
  This archive also contains the original CLI file, worktree metadata and patches.
- Left intentional ignored virtualenvs/caches and existing tracked branches alone.
  No source branches were deleted or force-pushed.

## ASUS registry configuration

In the separate ASUS DevOS checkout, commit `d0a44b5` registers `devchain` against
the system's locked `dotfiles` input. The generated system registry was built and
inspected successfully and resolves the alias to pinned source `0c3f9b1`.
After that configuration is applied, `nix shell devchain#toolset` and
`nix run devchain#nvim` work independently of the current directory. Updating this
alias to the final release requires updating DevOS's input and rebuilding.
No system activation, service restart or reboot was performed.

## Verification

- Native Apple Silicon `nix flake check --show-trace`: passed, including the
  installed-wrapper project-PATH regression checks and offline launcher build.
- Native ASUS x86_64 Linux `nix flake check --offline --show-trace` against a
  copied immutable release source: passed, without modifying the ASUS checkout.
- `nix flake show --all-systems --json`: all package, shell, formatter and check
  outputs evaluate for ARM64 Darwin, ARM64 Linux and x86_64 Linux.
- `nix fmt -- --check flake.nix nix/*.nix` and `git diff --check`: passed.
- Native `nix develop --command hatch run test`: 17 passed, one opt-in tmux test
  skipped; rerun with `DOTFILES_TEST_TMUX` set to the built package: **18 passed**,
  including actual Ctrl-A/Ctrl-S input to an attached tmux client.
- Built Ghostty/OpenCode artifacts and compared every emitted configuration file
  byte-for-byte with its tracked source.

ARM64 Linux is evaluation-only. Desktop clipboard delivery and graphical browser
rendering are not claimed by these checks.
