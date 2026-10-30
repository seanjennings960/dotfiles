#!/bin/sh
set -eu

test -x /opt/devchain/runtime/bin/dev
test "$(command -v dev)" = /usr/local/bin/dev
case "$(readlink -f /usr/local/bin/dev)" in
    /nix/store/*) ;;
    *) echo "dev must resolve to its immutable Nix package" >&2; exit 1 ;;
esac
pytest -q container_smoke.py
