# DevOS

DevOS packages this toolset as a NixOS single-app interface:

```text
NixOS → Cage (Wayland) → Ghostty → dev → tmux
```

Import the flake's `nixosModules.devos` and set `services.devos.enable = true`.
The module creates a normal user named `dev` (override with
`services.devos.user`) and automatically starts their graphical session.
The machine configuration owns passwords, disks, bootloader, and
`system.stateVersion`. Automatic graphical login is part of this module's
current interface.

The initial workspace is `~/workspaces`. Detaching presents a prompt: Enter
reconnects, `s` opens a recovery shell, and `q` requests shutdown. Cage allows
virtual-console switching for recovery. The machine configuration must provide
credentials for console login.

The tmux server runs in a separate user service so restarting the graphical
session does not place workspace processes in Cage's service cgroup. Inspect
it with `systemctl --user status devos-tmux`; inspect graphical startup with
`journalctl -u cage-tty1`.

Files and application state live in the user's home. A persistent home preserves
them across reboot; running processes do not survive reboot. tmux-resurrect's
manual snapshots currently omit the launcher's workspace tags, so restoration
does not yet guarantee automatic reconnection through `dev`.

## Local VM development

VM-specific configurations, builder provisioning, and launch instructions live
in the separate `~/code/dev/vm` repository. The first target is an ARM64 VM on
macOS; the planned physical target is an x86_64 PC.

The initial module has been evaluated against the pinned NixOS version. Boot,
rendering, clipboard, and restart/persistence validation are tracked in the VM
repository. Browser integration, installer media, and physical-machine support
follow the initial graphical boot milestone.
