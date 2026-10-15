#!/bin/sh
set -eu

NIX_VERSION=2.28.5
source_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

if [ "$#" -ne 0 ]; then
    printf '%s\n' 'Usage: sh ./install.sh' >&2
    exit 2
fi

if [ "$(id -u)" -eq 0 ]; then
    tools_dir=/opt/devchain
    bin_dir=/usr/local/bin
    package=default
    # Feature installation happens at image-build time, without an init system.
    # Keep these settings local to this installer, not in the user's nix.conf.
    export NIX_REMOTE=local
    NIX_CONFIG="${NIX_CONFIG:-}
build-users-group =
sandbox = false"
    export NIX_CONFIG
else
    tools_dir="$source_dir/.devtools"
    bin_dir="$tools_dir/bin"
    package=editable
fi

find_nix() {
    if command -v nix >/dev/null 2>&1; then
        command -v nix
    elif [ -x "${HOME:-}/.nix-profile/bin/nix" ]; then
        printf '%s\n' "$HOME/.nix-profile/bin/nix"
    elif [ -x /nix/var/nix/profiles/default/bin/nix ]; then
        printf '%s\n' /nix/var/nix/profiles/default/bin/nix
    else
        return 1
    fi
}

if ! nix=$(find_nix); then
    installer=$(curl --fail --silent --show-error --location \
        "https://releases.nixos.org/nix/nix-$NIX_VERSION/install")
    if [ "$package" = default ]; then
        if [ "$(uname -s)" != Linux ]; then
            printf '%s\n' 'Run host installation as your normal user; root installation is for Linux containers.' >&2
            exit 1
        fi
        mkdir -p /nix
        printf '%s\n' "$installer" | sh -s -- \
            --no-daemon --no-channel-add --no-modify-profile --yes
    else
        printf '%s\n' 'Installing system-wide Nix (may request sudo); dev remains checkout-local.'
        printf '%s\n' "$installer" | sh -s -- --daemon --no-channel-add --yes
    fi
    if ! nix=$(find_nix); then
        printf '%s\n' 'Nix installation did not provide a usable nix executable. Open a new shell and retry.' >&2
        exit 1
    fi
fi

# Copy only build inputs: path flakes otherwise include .git, project virtual
# environments, and the previous Nix output. This also works in a Feature bundle.
build_dir=$(mktemp -d)
trap 'rm -rf "$build_dir"' EXIT HUP INT TERM
cp "$source_dir/flake.nix" "$source_dir/flake.lock" "$source_dir/pyproject.toml" "$build_dir/"
cp -RL "$source_dir/dotfiles_dev" "$build_dir/"
mkdir -p "$tools_dir" "$bin_dir"
"$nix" --extra-experimental-features 'nix-command flakes' build \
    --no-update-lock-file --out-link "$tools_dir/runtime" "path:$build_dir#$package"

if [ "$package" = editable ]; then
    cat > "$build_dir/dev" <<'EOF'
#!/bin/sh
source_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd) || exit 1
export DEVCHAIN_SOURCE="$source_dir"
exec "$source_dir/.devtools/runtime/bin/dev" "$@"
EOF
    chmod +x "$build_dir/dev"
    # Replace an old uv launcher symlink instead of writing through its target.
    mv -f "$build_dir/dev" "$bin_dir/dev"
else
    ln -sfn "$tools_dir/runtime/bin/dev" "$bin_dir/dev"
fi
printf 'Installed dev. Add %s to PATH.\n' "$bin_dir"
