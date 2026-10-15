#!/bin/sh
set -eu

test -x /opt/devchain/tools/devchain/bin/dev
test "$(command -v dev)" = /usr/local/bin/dev
pytest -q container_smoke.py
