#!/usr/bin/env bash
# Compatibility entry point for explicit, offline activation.
set -euo pipefail
ROOT=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
launcher=${DOTFILES_LAUNCHER:-$HOME/.local/bin/dev}
if [[ ! -x $launcher ]]; then
    printf '%s\n' 'Missing launcher. Run make launcher-env in the Ubuntu devcontainer first.' >&2
    exit 1
fi
export DOTFILES_SOURCE="$ROOT"
exec "$launcher" --workspace "$ROOT" activate "$@"
