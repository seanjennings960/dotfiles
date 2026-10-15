#!/bin/sh
set -eu

UV_VERSION=0.13.1
PYTHON_VERSION=3.11.17
source_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

if [ "$(id -u)" -eq 0 ]; then
    tools_dir=/opt/devchain
    bin_dir=/usr/local/bin
else
    tools_dir="$source_dir/.devtools"
    bin_dir="$tools_dir/bin"
    set -- --editable "$@"
fi
export UV_TOOL_DIR="$tools_dir/tools"
export UV_TOOL_BIN_DIR="$bin_dir"
export UV_PYTHON_INSTALL_DIR="$tools_dir/python"
export UV_CACHE_DIR="$tools_dir/cache"

uv="$tools_dir/uv"
if [ ! -x "$uv" ]; then
    mkdir -p "$tools_dir"
    installer=$(curl --fail --silent --show-error --location "https://astral.sh/uv/$UV_VERSION/install.sh")
    printf '%s\n' "$installer" | UV_INSTALL_DIR="$tools_dir" \
        UV_NO_MODIFY_PATH=1 UV_NO_INSTALLER_METADATA=1 sh
fi

"$uv" tool install --python "$PYTHON_VERSION" --managed-python --force "$@" "$source_dir"
printf 'Installed dev. Add %s to PATH.\n' "$bin_dir"
