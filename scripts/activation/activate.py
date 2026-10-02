"""Offline activation with a complete preflight and rollback on write failure."""

import os
import stat
import subprocess
import sys
import tempfile
from pathlib import Path

BEGIN = b"# >>> dotfiles managed startup >>>"
END = b"# <<< dotfiles managed startup <<<"


def fail(message):
    raise ValueError(message)


def absolute_env(name, fallback=None):
    value = os.environ.get(name) or fallback
    if not value or not Path(value).is_absolute():
        fail(f"{name} must be an absolute path")
    return Path(value)


def writable_parent(path):
    parent = path.parent
    while not parent.exists():
        if parent.is_symlink():
            fail(f"Dangling parent symlink: {parent}")
        parent = parent.parent
    if not parent.is_dir() or not os.access(parent, os.W_OK | os.X_OK):
        fail(f"Unwritable destination parent: {parent}")


def startup_content(original, shell):
    # Byte-preserving outside our block, including non-UTF8 personal content.
    lines = original.splitlines(keepends=True)
    result = []
    inside = False
    for line in lines:
        marker = line.rstrip(b"\r\n")
        if marker == BEGIN:
            if inside:
                fail("Nested managed startup block")
            inside = True
        elif marker == END:
            if not inside:
                fail("Unmatched managed startup block end")
            inside = False
        elif not inside:
            result.append(line)
    if inside:
        fail("Unterminated managed startup block")
    content = b"".join(result)
    if content and not content.endswith(b"\n"):
        content += b"\n"
    source = '${XDG_CONFIG_HOME:-"$HOME/.config"}/dotfiles/' + shell
    block = f'if [ -r "{source}" ]; then\n    . "{source}"\nfi\n'.encode()
    return content + BEGIN + b"\n" + block + END + b"\n"


def replace_file(path, content, mode):
    fd, temporary = tempfile.mkstemp(prefix=".dotfiles-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(content)
            os.fchmod(stream.fileno(), mode)
        os.replace(temporary, path)
    finally:
        if os.path.lexists(temporary):
            os.unlink(temporary)


def activate(root):
    home = absolute_env("HOME")
    if not home.is_dir() or not os.access(home, os.W_OK | os.X_OK):
        fail("HOME must be an existing writable directory")
    config = absolute_env("XDG_CONFIG_HOME", str(home / ".config"))
    data = absolute_env("XDG_DATA_HOME", str(home / ".local/share"))
    state = absolute_env("XDG_STATE_HOME", str(home / ".local/state"))
    cache = absolute_env("XDG_CACHE_HOME", str(home / ".cache"))
    directories = [home / "bin", config, config / "dotfiles", config / "opencode",
                   data / "nvim", data / "opencode", state / "opencode",
                   cache / "nvim", cache / "opencode"]
    directories += [state / "nvim" / name for name in ("undo", "swap", "backup")]
    links = [(root / "nvim", config / "nvim"),
             (root / "tmux.conf", home / ".tmux.conf"),
             (root / "tmux/tmux_neww.sh", home / "bin/tmux_neww")]
    links += [(root / name, config / "dotfiles" / name)
              for name in ("bashrc", "bash_aliases", "zshrc")]
    links += [(root / "opencode" / name, config / "opencode" / name)
              for name in ("opencode.jsonc", "skills")]
    login = next((home / name for name in (".bash_profile", ".bash_login", ".profile")
                  if os.path.lexists(home / name)), home / ".profile")
    startup = [(home / ".bashrc", "bashrc"), (login, "bashrc"),
               (home / ".zshrc", "zshrc")]

    # No mutation until every source, destination, and startup file is checked.
    for path in directories + [p for _, p in links] + [p for p, _ in startup]:
        # Managed source links are expected to resolve into the repository.
        managed_link = any(path == dest and path.is_symlink() and
                           path.resolve() == source.resolve() for source, dest in links)
        if path.resolve().is_relative_to(root) and not managed_link:
            fail(f"Writable destination resolves into repository: {path}")
        writable_parent(path)
    for path in directories:
        if os.path.lexists(path) and (path.is_symlink() or not path.is_dir()):
            fail(f"Expected a user-owned directory: {path}")
        if path.exists() and not os.access(path, os.W_OK | os.X_OK):
            fail(f"Unwritable directory: {path}")
    pending_links = []
    for source, destination in links:
        if not source.exists():
            fail(f"Missing source: {source}")
        if source.name == "tmux_neww.sh" and not os.access(source, os.X_OK):
            fail(f"Source must be executable: {source}")
        if os.path.lexists(destination):
            if destination.is_symlink() and destination.resolve() == source.resolve():
                continue
            fail(f"Conflict (preserved): {destination}")
        pending_links.append((source, destination))
    pending_files = []
    for path, shell in startup:
        exists = os.path.lexists(path)
        if exists and (path.is_symlink() or not path.is_file()):
            fail(f"Startup file must be a regular file (preserved): {path}")
        if exists and not os.access(path, os.W_OK):
            fail(f"Unwritable startup file: {path}")
        original = path.read_bytes() if exists else None
        mode = stat.S_IMODE(path.stat().st_mode) if exists else 0o644
        content = startup_content(original or b"", shell)
        if content != original:
            pending_files.append((path, original, content, mode))

    created_dirs, created_links, changed_files = [], [], []

    def mkdir(path):
        if path.exists():
            return
        mkdir(path.parent)
        path.mkdir(mode=0o700)
        created_dirs.append(path)

    try:
        for path in directories:
            mkdir(path)
        for source, destination in pending_links:
            # External ln makes failures visible and testable; never replace conflicts.
            subprocess.run(["ln", "-s", str(source), str(destination)], check=True)
            created_links.append(destination)
        for path, original, content, mode in pending_files:
            replace_file(path, content, mode)
            changed_files.append((path, original, mode))
    except (OSError, subprocess.CalledProcessError):
        for path, original, mode in reversed(changed_files):
            if original is None:
                path.unlink()
            else:
                replace_file(path, original, mode)
        for path in reversed(created_links):
            path.unlink()
        for path in reversed(created_dirs):
            path.rmdir()
        raise
    print("Dotfiles activated (offline); existing personal configuration preserved.")


if __name__ == "__main__":
    try:
        if len(sys.argv) != 2:
            fail("Usage: ./install.sh (no arguments)")
        activate(Path(sys.argv[1]).resolve())
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"Activation failed: {error}", file=sys.stderr)
        sys.exit(1)
