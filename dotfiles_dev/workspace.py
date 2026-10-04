"""Workspace identity and invocation directory, without project configuration."""

from dataclasses import dataclass
from pathlib import Path
import os
import subprocess

import click


@dataclass(frozen=True)
class Workspace:
    root: Path
    cwd: Path
    git_metadata_available: bool = True

    @classmethod
    def discover(cls, explicit=None):
        invocation = Path.cwd()
        metadata_available = True
        if explicit is not None:
            root = Path(explicit).expanduser().resolve()
            if not root.is_dir():
                raise click.ClickException(f"Workspace is not a directory: {root}")
        else:
            # Inherited Git overrides must not select another worktree.
            environment = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
            try:
                result = subprocess.run(
                    ["git", "-C", str(invocation), "rev-parse", "--show-toplevel"],
                    env=environment, capture_output=True, text=True, check=False,
                )
            except FileNotFoundError:
                raise click.ClickException("Missing tool: git. Install it explicitly before discovery.")
            if result.returncode == 0:
                root = Path(result.stdout.rstrip("\n")).resolve()
            else:
                root = invocation
                # A bind-mounted linked worktree can retain its .git file while
                # the host's metadata path is unreachable in this container.
                # Discover the writable workspace without pretending Git works.
                for parent in (invocation, *invocation.parents):
                    marker = parent / ".git"
                    if marker.is_file() and marker.read_text().startswith("gitdir: "):
                        root = parent
                        metadata_available = False
                        break
        cwd = invocation if invocation.is_relative_to(root) else root
        return cls(root, cwd, metadata_available)
