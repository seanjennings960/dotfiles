# tmux and session recovery

## Start the configured tmux

From the repository root:

```sh
nix shell .#toolset
tmux -L devchain new-session -s work
```

The packaged tmux loads the repository's configuration and tmux-resurrect.
The plugin is installed by Nix; no TPM installation or plugin download is needed.
The legacy `infectdots.sh` workflow alone does not load resurrect.

`-L devchain` selects a named tmux server. Use the same name in later commands.
Configuration is loaded when the server starts; launching another client does
not reconfigure an already-running server.

## Save and restore

The prefix is **Ctrl-A**. Press it, release it, then press the next key:

| Keys | Action |
| --- | --- |
| Ctrl-A, Ctrl-S | Save a snapshot of all sessions on this server. |
| Ctrl-A, Ctrl-R | Restore the latest snapshot. |
| Ctrl-A, d | Detach, leaving sessions running. |
| Ctrl-A, r | Reload the packaged tmux configuration. |

Save after arranging your windows and panes, and before a reboot. Wait for the
"Tmux environment saved!" message. Saving and restoring are manual; there is no
automatic periodic save or startup restore.

After rebooting, enter the toolset and start a temporary session:

```sh
nix shell .#toolset
tmux -L devchain new-session -s recovery
```

Press **Ctrl-A, Ctrl-R**. Resurrect recreates the saved sessions, windows, pane
layouts, working directories, and supported commands. Use **Ctrl-A, s** to
choose a restored session.

Resurrect does not checkpoint process memory or unsaved editor buffers. Save
files before shutting down. Arbitrary running jobs are not guaranteed to restart.

## Reconnect without restoring

If the tmux server is still running, simply attach:

```sh
tmux -L devchain list-sessions
tmux -L devchain attach-session -t work
```

Detaching or closing your terminal normally leaves tmux running. Restoring is
for recovering saved layouts after the server has stopped, such as after a reboot.

## Snapshot files and the dev launcher

Snapshots live in `~/.tmux/resurrect/`; `last` points to the latest snapshot.
This directory is writable and separate from the Nix store. By default it is
shared by your tmux servers, so a save from another server changes which snapshot
Ctrl-A, Ctrl-R restores.

The `dev` launcher uses a server named `dotfiles-dev`. To inspect or attach to
its sessions directly, use `tmux -L dotfiles-dev list-sessions` and
`tmux -L dotfiles-dev attach-session -t <session-name>`.

Resurrect does not preserve the launcher's custom workspace/environment tags.
After restoring, attach to the restored session directly: running `dev` may
create a new session because those tags are missing.

## Check that resurrect is loaded

From a pane in the server you want to inspect:

```sh
tmux show-option -gv @resurrect-save-script-path
tmux show-option -gv @resurrect-restore-script-path
```

Both should print plugin script paths in `/nix/store`. If the options are absent,
check that you started the packaged tmux on a fresh server. For a separate test
server, run `nix run .#tmux -- -L resurrect-test new-session` from the repository.
