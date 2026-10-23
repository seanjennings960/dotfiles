# Devchain Feature

`src/devchain` links to the root installer, flake and lockfile, package metadata,
and `dotfiles_dev/`. `test/devchain` links to `tests/`. The Feature and host
installation use the same installer, package source, and tests.

`install.sh` reuses installed Nix or downloads the official Nix installer with
curl. A first host installation requires sudo to create the system-wide `/nix`
store and configure the standard Nix daemon. Root container builds use a
single-user installation without a daemon. `flake.nix` and `flake.lock` pin the
launcher's Python runtime and dependencies.

Host installations build `packages.editable` to `.devtools/runtime`; the
`.devtools/bin/dev` wrapper loads the live checkout. Container installations build
`packages.default` to `/opt/devchain/runtime`, with `dev` on PATH at
`/usr/local/bin/dev`. Container package code and dependencies live in `/nix/store`,
so the Feature staging directory is not needed after installation. The runtime
output links are Nix garbage-collection roots. Re-run `install.sh` after moving a
host checkout to update its wrapper and root.

The base image must supply curl, CA certificates, tar, and xz for the official Nix
installer. Git and tmux are runtime dependencies; projects supply these alongside
any editors or shells they want. The installer does not require system Python or
pip.

## Build and test

From the repository root:

```sh
make build
make test
make smoke
```

`build` is the default target. `test` and `smoke` both depend on it. The Feature
test uses Dev Container CLI to install the Feature again and run
`tests/container_smoke.py` as `vscode`. The smoke target exercises the repository's
own devcontainer and removes its test container afterwards. These checks run the
installed CLI with a project virtual environment, verify isolation from project
Python variables, and enter tmux through a terminal to check reconnection.

`make feature` copies the Feature into `.devcontainer/features/devchain`, following
the source links. This makes a self-contained build input under the consuming
project's `.devcontainer` directory, as required for a local Feature. There is no
separate preparation script. `devcontainer up` runs this target through the
initialize hook. The generated directory is ignored by Git.

## Use in another project

Copy the Feature with its links dereferenced:

```sh
mkdir -p ../my-project/.devcontainer/features
cp -RL features/src/devchain ../my-project/.devcontainer/features/
```

Add `"./features/devchain": {}` to that project's `features` configuration.

To create a distributable Feature archive:

```sh
make feature
devcontainer features package .devcontainer/features/devchain
```

## Execution contract

The Feature sets `DEV_ENVIRONMENT=container`. In a container, bare `dev` reconnects
to local tmux work, `dev env` reports container context, and `dev exec` executes
locally with the caller's working directory and streams. Project virtual
environments keep their own Python and packages. The launcher rejects requests
to enter a different environment.
