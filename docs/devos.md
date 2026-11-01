# DevOS

## Bootable PC ISO

The flake exposes `packages.x86_64-linux.devos-iso`, built from the pinned
Devchain `toolset`: `dev`, configured tmux, Neovim, Zsh, and OpenCode. Ghostty
and Cage provide the graphical entry point. These packages and their runtime
dependencies are included in the image; boot does not install them.

On x86_64 Linux:

```sh
nix build .#devos-iso
ls -lh result/iso/devos-x86_64.iso
```

The ISO uses NixOS's live installation-media support, with UEFI and hybrid USB
boot enabled. It opens the DevOS interface as `dev`; console credentials are
`dev` / `dev`. The live session uses a RAM overlay. It includes NixOS's standard
installation tools, but does not automatically install onto a disk. Secure Boot
signing and hardware-specific installation configuration are not provided.

On this ARM64 Mac, `~/code/dev/vm` owns Linux build emulation, ISO copying, and
QEMU boot verification. The ISO definition itself lives in
`nix/nixos/live-iso.nix`, so it can be built directly on a native Linux machine.

## System interface

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

The ARM64 EFI disk image has built and booted into Ghostty/tmux on macOS QEMU.
Automated serial-console checks verify graphical attachment, workspace tags,
pane-process survival across a Cage restart, and workspace-file persistence
across reboot. The VM repository tracks the remaining interactive clipboard,
keyboard, and application-state checks.

Linux builds run inside Lima. A dedicated artifact-copy script verifies and
copies the self-contained image back to the Mac; host Nix trust settings remain
unchanged. Browser integration, installer media, and physical-machine support
follow the initial graphical boot milestone.
