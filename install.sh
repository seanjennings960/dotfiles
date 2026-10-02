#!/usr/bin/env bash
# Canonical, offline user activation. Tool provisioning is a separate step.
set -euo pipefail
ROOT=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
exec python3 "$ROOT/scripts/activation/activate.py" "$ROOT" "$@"
