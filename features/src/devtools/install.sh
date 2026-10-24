#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "The devtools Feature must run as root during image construction." >&2
    exit 1
fi
feature_dir=$(pwd -P)
launcher_source="$feature_dir/launcher"
if [ ! -f "$launcher_source/pyproject.toml" ]; then
    echo "Missing launcher payload. Run scripts/prepare_feature.py first." >&2
    exit 1
fi

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates git python3 python3-venv tmux vim zsh
rm -rf /var/lib/apt/lists/*

# Use the distribution interpreter, never a project's active Python environment.
/usr/bin/python3 -c 'import sys; assert sys.version_info >= (3, 11), "dev requires Python 3.11 or newer"'
destination=/opt/dotfiles-dev
if [ -e /usr/local/bin/dev ] && [ "$(readlink /usr/local/bin/dev)" != "$destination/venv/bin/dev" ]; then
    echo "An existing /usr/local/bin/dev is not owned by this Feature." >&2
    exit 1
fi
mkdir -p "$destination"
/usr/bin/python3 ./launcher/dotfiles_dev/install_launcher.py \
    --python /usr/bin/python3 \
    --venv "$destination/venv" \
    --source "$launcher_source" \
    --force-reinstall
ln -sfn "$destination/venv/bin/dev" /usr/local/bin/dev
cp ./source.json "$destination/source.json"
