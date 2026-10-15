#!/bin/sh
set -eu

test -x /opt/dotfiles-dev/venv/bin/dev
test "$(command -v dev)" = /usr/local/bin/dev

environment=$(dev env)
printf '%s\n' "$environment" | grep -q '^Environment: container$'
