#!/usr/bin/env bash
# Explicit development setup, never called by entry or dev test.
set -euo pipefail

if [[ $(uname -s) != Linux ]]; then
    printf '%s\n' 'Launcher setup currently supports the Linux devcontainer only.' >&2
    exit 1
fi

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
launcher="$HOME/.local/share/dotfiles/launcher"
/usr/bin/python3 -I -m venv "$launcher"
"$launcher/bin/python" -I -m pip install -r "$source_dir/requirements-launcher.lock"
"$launcher/bin/python" -I -m pip install --no-build-isolation --no-deps -e "$source_dir"
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/dev" <<EOF
#!/bin/sh
exec "$launcher/bin/python" -I "$launcher/bin/dev" "\$@"
EOF
chmod 0755 "$HOME/.local/bin/dev"
printf 'Launcher: %s\n' "$HOME/.local/bin/dev"
