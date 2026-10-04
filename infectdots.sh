#!/usr/bin/env bash
# Compatibility entry point; all activation uses the isolated launcher runtime.
set -euo pipefail
ROOT=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
exec "$ROOT/install.sh" "$@"
