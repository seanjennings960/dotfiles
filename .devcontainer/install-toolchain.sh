#!/usr/bin/env bash
# Run during image provisioning, never during user activation.
set -euo pipefail

case "$(uname -m)" in
    aarch64)
        node_arch=arm64
        nvim_arch=arm64
        ruff_arch=aarch64
        opencode_arch=arm64
        node_sha=4181609e03dcb9880e7e5bf956061ecc0503c77a480c6631d868cb1f65a2c7dd
        nvim_sha=1aa5ca085249580ae0f91eb14f27ec0919773ff2d99a163d03f3d6c21ac29725
        ruff_sha=dc0d74de837ef0a7bcc62ce98c48a622b075d057161f13b958be2934becd55a6
        opencode_sha=bbdb3f00c2c51e42e315525233151309724226a8776da8e9145e3b0fa3d5310f
        ;;
    x86_64)
        node_arch=x64
        nvim_arch=x86_64
        ruff_arch=x86_64
        opencode_arch=x64
        node_sha=eeaccb0378b79406f2208e8b37a62479c70595e20be6b659125eb77dd1ab2a29
        nvim_sha=bce0f56eda1f1b1db6eee8f4133d7a38813ea07933837dd1777411ca384c6875
        ruff_sha=9567ff1201e2fb3da31ff04c35587d768c66d6cb42dfa84de474e2bfe360b608
        opencode_sha=24b0d458d21ef548b2752166303defcf7f4945b049fb4876ab78dfaf86d81b27
        ;;
    *) printf 'Unsupported architecture: %s\n' "$(uname -m)" >&2; exit 1 ;;
esac

source_dir=$(dirname -- "$(realpath -- "${BASH_SOURCE[0]}")")
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

download() {
    local url=$1 checksum=$2 destination=$3
    curl --fail --location --retry 3 --output "$destination" "$url"
    printf '%s  %s\n' "$checksum" "$destination" | sha256sum --check --status
}

mkdir -p /opt/dotfiles/node /opt/dotfiles/nvim /opt/dotfiles/checkers
download "https://nodejs.org/dist/v22.20.0/node-v22.20.0-linux-${node_arch}.tar.gz" "$node_sha" "$scratch/node.tar.gz"
tar -xzf "$scratch/node.tar.gz" -C /opt/dotfiles/node --strip-components=1
download "https://github.com/neovim/neovim/releases/download/v0.12.5/nvim-linux-${nvim_arch}.tar.gz" "$nvim_sha" "$scratch/nvim.tar.gz"
tar -xzf "$scratch/nvim.tar.gz" -C /opt/dotfiles/nvim --strip-components=1
ln -s /opt/dotfiles/nvim/bin/nvim /usr/local/bin/nvim

download "https://github.com/astral-sh/ruff/releases/download/0.16.10/ruff-${ruff_arch}-unknown-linux-gnu.tar.gz" "$ruff_sha" "$scratch/ruff.tar.gz"
tar -xzf "$scratch/ruff.tar.gz" -C "$scratch"
install -m 0755 "$scratch/ruff-${ruff_arch}-unknown-linux-gnu/ruff" /usr/local/bin/ruff
download "https://github.com/anomalyco/opencode/releases/download/v1.18.34/opencode-linux-${opencode_arch}.tar.gz" "$opencode_sha" "$scratch/opencode.tar.gz"
tar -xzf "$scratch/opencode.tar.gz" -C "$scratch"
install -m 0755 "$scratch/opencode" /usr/local/bin/opencode

cp "$source_dir/package.json" "$source_dir/package-lock.json" /opt/dotfiles/checkers/
PATH="/opt/dotfiles/node/bin:$PATH" /opt/dotfiles/node/bin/npm ci \
    --prefix /opt/dotfiles/checkers --omit=dev --ignore-scripts --no-audit --no-fund
# Pin the checker's execution runtime even when a project supplies another node.
for checker in pyright pyright-langserver; do
    entry=index.js
    if [[ $checker == pyright-langserver ]]; then entry=langserver.index.js; fi
    cat > "/usr/local/bin/$checker" <<EOF
#!/bin/sh
exec /opt/dotfiles/node/bin/node /opt/dotfiles/checkers/node_modules/pyright/$entry "\$@"
EOF
    chmod 0755 "/usr/local/bin/$checker"
done

nvim --version
ruff --version
pyright --version
opencode --version
