#!/usr/bin/env bash
# Compatibility entry point; keep all activation policy in install.sh.
set -euo pipefail
ROOT=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
exec "$ROOT/install.sh" "$@"
