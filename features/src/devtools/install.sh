#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "The devtools Feature must run as root during image construction." >&2
    exit 1
fi
if [ ! -f ./source/pyproject.toml ]; then
    echo "Missing launcher payload. Run scripts/prepare_feature.py first." >&2
    exit 1
fi

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    bash-completion ca-certificates curl git ncurses-term python3 python3-venv \
    python-is-python3 ripgrep tmux vim zsh
rm -rf /var/lib/apt/lists/*

# The Dev Container CLI normalizes Feature files to 0755. Restore source modes
# and verify the prepared payload before installing it.
python3 - <<'PY'
import hashlib
import json
from pathlib import Path
for name, entry in json.loads(Path("source.json").read_text()).items():
    path = Path(name)
    if hashlib.sha256(path.read_bytes()).hexdigest() != entry["sha256"]:
        raise SystemExit(f"Feature payload hash mismatch: {name}")
    path.chmod(entry["mode"])
PY

# Use the distribution interpreter, never a project's active Python environment.
/usr/bin/python3 -c 'import sys; assert sys.version_info >= (3, 11), "dev requires Python 3.11 or newer"'
destination=/opt/dotfiles-dev
if [ -e /usr/local/bin/dev ] && [ ! -f "$destination/source.json" ]; then
    echo "An existing /usr/local/bin/dev is not owned by this Feature." >&2
    exit 1
fi
mkdir -p "$destination"
if [ -e "$destination/source" ]; then
    test -f "$destination/source.json" || { echo 'Unowned Feature source directory' >&2; exit 1; }
    rm -rf "$destination/source"
fi
cp -R ./source "$destination/source"
/usr/bin/python3 -m venv "$destination/venv"
"$destination/venv/bin/python" -I -m pip install --no-cache-dir -r "$destination/source/requirements-launcher.lock"
# The build backend is supplied by the lock above, so isolated build downloads
# would introduce a second, unpinned setuptools selection.
"$destination/venv/bin/python" -I -m pip install --no-build-isolation --no-deps -e "$destination/source"
rm -f /usr/local/bin/dev
cat > /usr/local/bin/dev <<'EOF'
#!/bin/sh
exec /opt/dotfiles-dev/venv/bin/python -I /opt/dotfiles-dev/venv/bin/dev "$@"
EOF
chmod 0755 /usr/local/bin/dev
bash ./install-toolchain.sh
cp ./source.json "$destination/source.json"
