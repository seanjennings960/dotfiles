# tmux

The supported default shell is Bash. Install `tmux/tmux_neww.sh` as
`tmux_neww` on the tmux server's `PATH` (the existing installer uses `~/bin`).
The configuration targets Ubuntu tmux 3.4, including child-specific `-e`
environment settings. Reload with **Ctrl-a r**.

## Keys

All shortcuts below start with **Ctrl-a**, except keys used inside copy mode.

| Key | Action |
| --- | --- |
| Ctrl-a | Forward Ctrl-a to the program or nested tmux |
| `\|` | Split horizontally (side by side) |
| `_` | Split vertically (above/below) |
| `c` | New window |
| `g` | Move space-separated window indexes into a new session |
| `h`, `j`, `k`, `l` or arrows | Select left/down/up/right pane |
| Ctrl-h/j/k/l | Resize five cells left/down/up/right; repeatable |
| Alt-h | Main-horizontal layout; repeatable |
| Ctrl-s/q/w | Main-vertical/even-horizontal/even-vertical layouts |
| `r` | Reload `~/.tmux.conf` |
| `[` | Enter vi copy mode |
| `P` | Paste tmux's buffer |

In copy mode, navigate with vi keys, press `v` to begin selecting, then `y`
to copy and leave copy mode. Escape cancels. Ctrl-a Ctrl-a is reserved for
prefix forwarding; main-horizontal formerly overwrote that binding.

The `g` prompt calls `dev windows pop`. It preflights indexes and client context,
moves stable window IDs, and preserves running pane processes. Moving some
windows keeps the original primary workspace; moving all transfers workspace
metadata to the new session, so a fresh launcher reconnects there. Invalid
indexes fail before moving anything. A backend failure after a partial move
reports the surviving destination instead of killing its processes.

## Logical directory contract

Shell startup and directory tracking publish logical
`$PWD` to the server's **global** environment:

```bash
tmux set-environment -g "TMUX_${TMUX_PANE}_PATH" "$PWD"
```

`tmux_neww {-h|-v|-w} %pane_id` reads that specific pane's key. It validates
the requested pane and uses an existing absolute logical directory, falling
back to `pane_current_path` when the key is absent, empty, relative, or points
to a missing/dangling directory. Invalid arguments or panes fail nonzero.
Splits explicitly target that pane; windows target its session, irrespective
of the attached client's active pane/session.

Creation uses quoted `tmux -c "$path"` and a child-only
`-e "DOTFILES_START_DIR=$path"`. The child shell must perform
`builtin cd -- "$DOTFILES_START_DIR"` at startup, then unset
`DOTFILES_START_DIR`, and record its logical `$PWD`. This restores symlink
spelling even though the process cwd is physical. No session/global startup
handoff is used: simultaneous requests cannot exchange directories. The old
`NEWW` handoff is retired. The activated Bash and Zsh snippets implement this
startup contract.

## Headless clipboard / Ghostty

tmux uses `set-clipboard on` and OSC52 to send copied text to the attached
terminal. Copying also populates the tmux buffer for `P`. No X11/Wayland
clipboard program is required on the remote host. The advertised clipboard
capability includes `xterm-256color` and `xterm-ghostty`; tmux's inner terminal
remains `screen-256color`.

If the remote host lacks `xterm-ghostty` terminfo, use
`TERM=xterm-256color tmux` as the compatibility setting for the SSH session.
Alternatively install Ghostty's terminfo on the host following Ghostty's SSH
documentation before using its native terminal name. No terminfo package is
added by this step.

Manual check from Ghostty over SSH:

1. Attach tmux, print a recognizable line, and use Ctrl-a `[` then vi
   navigation, `v`, and `y` to copy it.
2. Paste into a **local** application and confirm the selected text arrives.
   Ghostty must permit terminal clipboard writes.
3. Use Ctrl-a `P` in tmux to verify its independent paste buffer.
4. Test a directory with spaces and a symlink using `|`, `_`, and `c`;
   compare `pwd -L` in parent and child shells.

`tests/test_tmux.py` attaches an isolated PTY client and verifies actual key
sequences, buffers, and emitted OSC52 bytes with terminal capabilities. It
does not assert that a host clipboard changed. Its minimal Bash startup
implements the shared contract independently. Shell tests exercise the real
snippets; window tests exercise activated tmux with an attached prompt and
fresh-launcher reconnection. Manual host-clipboard delivery remains unverified.

PR #8 overlaps the creation bindings with a native-command workaround that
uses physical `pane_current_path`. This step retains a scoped helper because
logical symlink preservation is required.
